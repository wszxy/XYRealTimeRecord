//
//  ViewController.m
//  XYRealTimeRecord
//
//  Created by zxy on 2017/3/17.
//  Copyright © 2017年 zxy. All rights reserved.
//

#import "ViewController.h"
#import "XYRecorder.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UIButton *startButton;
@property (weak, nonatomic) IBOutlet UIButton *stopButton;
@property (nonatomic, strong) XYRecorder *recorder;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.

    _recorder = [[XYRecorder alloc] init];
    self.stopButton.enabled = FALSE;

}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)startRecord:(id)sender {
    [_recorder startRecorder];
    
    self.startButton.enabled = FALSE;
    self.stopButton.enabled = TRUE;
}

- (IBAction)stopRecorder:(id)sender {
    [_recorder stopRecorder];
    
    self.startButton.enabled = TRUE;
    self.stopButton.enabled = FALSE;
}

@end
