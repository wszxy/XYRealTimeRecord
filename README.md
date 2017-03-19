# XYRealTimeRecord
---
### 配置AudioSession
和其他录音播放一样，需要配置录音播放的环境，响应耳机事件等。

    NSError *error;
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    [audioSession setPreferredSampleRate:44100 error:&error];
    [audioSession setPreferredInputNumberOfChannels:1 error:&error];
    [audioSession setPreferredIOBufferDuration:0.05 error:&error];

---
### 配置AudioComponentDescription
AudioComponentDescription是用来描述unit 的类型，包括均衡器，3D混音，多路混音，远端输入输出，VoIP输入输出，通用输出，格式转换等，在这里使用远端输入输出。

    AudioComponentDescription audioDesc;
    audioDesc.componentType = kAudioUnitType_Output;
    audioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioDesc.componentFlags = 0;
    audioDesc.componentFlagsMask = 0;
    
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &audioDesc);
    AudioComponentInstanceNew(inputComponent, &audioUnit);

---
### 配置输入输出的数据格式
设置采样率为44100，单声道，16位的格式，注意输入输出都要设置。

    AudioStreamBasicDescription audioFormat;
    audioFormat.mSampleRate = 44100;
    audioFormat.mFormatID = kAudioFormatLinearPCM;
    audioFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    audioFormat.mFramesPerPacket = 1;
    audioFormat.mChannelsPerFrame = 1;
    audioFormat.mBitsPerChannel = 16;
    audioFormat.mBytesPerPacket = 2;
    audioFormat.mBytesPerFrame = 2;
    
    AudioUnitSetProperty(audioUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Output,
                         INPUT_BUS,
                         &audioFormat,
                         sizeof(audioFormat));
    AudioUnitSetProperty(audioUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Input,
                         OUTPUT_BUS,
                         &audioFormat,
                         sizeof(audioFormat));
---                         
### 打开输入输出端口
在默认情况下，输入是关闭的，输出是打开的。在unit的Element中，Input用“1”（和I很像）表示，Output用“0”（和O很像）表示。

    UInt32 flag = 1;
    
    AudioUnitSetProperty(audioUnit,
                         kAudioOutputUnitProperty_EnableIO,
                         kAudioUnitScope_Input,
                         INPUT_BUS,
                         &flag,
                         sizeof(flag));
    AudioUnitSetProperty(audioUnit,
                         kAudioOutputUnitProperty_EnableIO,
                         kAudioUnitScope_Input,
                         OUTPUT_BUS,
                         &flag,
                         sizeof(flag));
                         
---
### 配置回调
根据应用的场景需求，可以在输入输出设置回调，以输入回调为例：

    AURenderCallbackStruct recordCallback;
    recordCallback.inputProc = RecordCallback;
    recordCallback.inputProcRefCon = (__bridge void *)self;
    AudioUnitSetProperty(audioUnit,
                         kAudioOutputUnitProperty_SetInputCallback,
                         kAudioUnitScope_Global,
                         INPUT_BUS,
                         &recordCallback,
                         sizeof(recordCallback));

需要定义回调函数，回调函数是AURenderCallback类型的，按照AUComponent.h中定义的参数类型，定义出输入回调函数：

    static OSStatus RecordCallback(void *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList *ioData)
    {

    AudioUnitRender(audioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, buffList);

    return noErr;
    }
    
---
### 分配缓存
这是获取录音数据很重要的一步，需要分配缓存来存储实时的录音数据。如果不这样做，录音数据也可以在输出的时候获取，但意义不一样，获取录音数据应该在输入回调中完成，而不是输出回调。

    UInt32 flag = 0;
    AudioUnitSetProperty(audioUnit,
                         kAudioUnitProperty_ShouldAllocateBuffer,
                         kAudioUnitScope_Output,
                         INPUT_BUS,
                         &flag,
                         sizeof(flag));
    
    buffList = (AudioBufferList*)malloc(sizeof(AudioBufferList));
    buffList->mNumberBuffers = 1;
    buffList->mBuffers[0].mNumberChannels = 1;
    buffList->mBuffers[0].mDataByteSize = 2048 * sizeof(short);
    buffList->mBuffers[0].mData = (short *)malloc(sizeof(short) * 2048);

通过以上设置，可以实时录音，并实时播放（本例中，输入输出都打开了）。

---
### 几个问题
1. 在真机上运行的时候，会报错，错误信息如下： 

![真机运行错误信息](http://upload-images.jianshu.io/upload_images/4758290-6ab1192b541fc3c4.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

这是因为没有开启录音权限，以source code的方式打开Info.plist文件，在dict标签中加入以下属性：

    <key>NSMicrophoneUsageDescription</key>
    <string>microphoneDesciption</string>
再次运行，就OK了。

2.回调时间间隔问题。
Audio Unit的延迟很低，回调时间非常稳定，很适合严格地实时处理音频，即使把时间设置成0.000725623582766秒，回调时间依然很准：

![回调间隔很短](http://upload-images.jianshu.io/upload_images/4758290-d1e82ec2593e55aa.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

事实上，Audio Unit没有回调间隔的配置，但是我们可以通过上下文环境配置，即：

    [audioSession setPreferredIOBufferDuration:0.05 error:&error];
这样设置duration为0.05秒，表示每隔0.05秒就去读取缓存数据。假设采样率为44100，采样位数16，这时buffer大小应该为44100 * 0.05 * 16 / 8 = 4410，但是，**Audio Unit 的buffer的大小是2的幂次方**，那么就不可能有4410，这时buffer实际大小为4096，反过来计算时间就是0.464秒，这也就解释了在Audio Queue中近似计算回调时间的原因了。
除此之外，如果不用AudioSession设置时间的话，会有一个默认大小的buffer，这个大小在模拟器和真机上不相同，所以为了程序可控，这个设置很有必要。

3.关于播放问题
测试发现，用耳机的效果更好，不用耳机在播放的时候会有噪声。如果想获得清晰的效果，可以将每次的PCM数据写入到文件，然后回放。推荐使用Lame，这个可以将PCM转换成MP3。

4.读取PCM数据
PCM数据存放在AudioBuffer的结构体中，音频数据是void *类型的数据：

    /*!
	    @struct         AudioBuffer
	    @abstract       A structure to hold a buffer of audio data.
	    @field          mNumberChannels
	                        The number of interleaved channels in the buffer.
	    @field          mDataByteSize
	                        The number of bytes in the buffer pointed at by mData.
	    @field          mData
	                        A pointer to the buffer of audio data.
	*/
	struct AudioBuffer
	{
	    UInt32              mNumberChannels;
	    UInt32              mDataByteSize;
	    void* __nullable    mData;
	};
	typedef struct AudioBuffer  AudioBuffer;

  如果采样位数是16位，即2Byte，即mData中每2Byte是一个PCM数据，以获取第一个数据为例：

    short *data = (short *)buffList->mBuffers[0].mData;
    NSLog(@"%d", data[0]);
**这里需要注意的就是类型转换的时候位数要一致。**
