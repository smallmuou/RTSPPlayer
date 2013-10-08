//
//  ViewController.m
//  RTSPPlayer
//
//  Created by xuwf on 13-8-19.
//  Copyright (c) 2013年 xuwf. All rights reserved.
//

#import "ViewController.h"

@interface ViewController () {
}
@end

@implementation ViewController
@synthesize playerViewController = _playerViewController;

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    [self.urlTextView setText:@"rtsp://192.168.2.210:554/ch1/0"];
    _playerViewController = [[RTSPPlayerViewController alloc] init];
    [_playerViewController.view setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight];

    [_playerViewController.view setFrame:CGRectMake(200, 100, 500, 920)];
    [self.view addSubview:_playerViewController.view];
}

- (IBAction)onPlayButtonPressed:(id)sender {
    [_urlTextView resignFirstResponder];
    
    [_playerViewController setContentURL:self.urlTextView.text];
    [_playerViewController play];
}

- (IBAction)onStopButtonPressed:(id)sender {
    [_playerViewController stop];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
