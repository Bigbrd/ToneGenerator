//
//  ToneGeneratorViewController.h
//  ToneGenerator
//
//  Changed and Applied by Bryan Dickens 4/29/2015
//
//  Initially started by Matt Gallagher on 2010/10/20.
//  Copyright 2010 Matt Gallagher. All rights reserved.
//
//  Permission is given to use this source code file, free of charge, in any
//  project, commercial or otherwise, entirely at your risk, with the condition
//  that any redistribution (in part or whole) of source code must retain
//  this copyright and permission notice. Attribution in compiled projects is
//  appreciated but not required.
//

#import <UIKit/UIKit.h>
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>
#import <MessageUI/MessageUI.h>
#import <MessageUI/MFMailComposeViewController.h>

@interface ToneGeneratorViewController : UIViewController <UIActionSheetDelegate, MFMailComposeViewControllerDelegate>
{
	UILabel *frequencyLabel;
	UIButton *playButton;
	UISlider *frequencySlider;
	AudioComponentInstance toneUnit;
    AVAudioRecorder *recorder;
    AVAudioSession *audioSession;
    NSTimer *levelTimer;
    double lowPassResults;

@public
	double frequency;
	double sampleRate;
	double theta;
    BOOL allowRecording;
}

@property (nonatomic, retain) IBOutlet UISlider *frequencySlider;
@property (nonatomic, retain) IBOutlet UIButton *playButton;
@property (nonatomic, retain) IBOutlet UIButton *recordButton;
@property (nonatomic, retain) IBOutlet UIButton *exportButton;
@property (nonatomic, retain) IBOutlet UILabel *frequencyLabel;

- (IBAction)sliderChanged:(UISlider *)frequencySlider;
- (IBAction)togglePlay:(UIButton *)selectedButton;
- (IBAction)exportButton:(UIButton *)selectedButton;
- (void)stop;
- (void)levelTimerCallback:(NSTimer *)timer;

@end

