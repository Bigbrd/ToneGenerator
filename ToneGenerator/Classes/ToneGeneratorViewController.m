//
//  ToneGeneratorViewController.m
//  ToneGenerator
//
//

#import "ToneGeneratorViewController.h"
#import <AudioToolbox/AudioToolbox.h>


OSStatus RenderTone(
	void *inRefCon, 
	AudioUnitRenderActionFlags 	*ioActionFlags, 
	const AudioTimeStamp 		*inTimeStamp, 
	UInt32 						inBusNumber, 
	UInt32 						inNumberFrames, 
	AudioBufferList 			*ioData)

{
	// Fixed amplitude
	const double amplitude = 0.25;

	// Get the tone parameters out of the view controller
	ToneGeneratorViewController *viewController =
		(ToneGeneratorViewController *)inRefCon;
	double theta = viewController->theta;
	double theta_increment = 2.0 * M_PI * viewController->frequency / viewController->sampleRate;
	// This is a mono tone generator so we only need the first buffer
	const int channel = 0;
	Float32 *buffer = (Float32 *)ioData->mBuffers[channel].mData;
    
    NSString *frequencyString = [NSString stringWithFormat:@"%d", (int)viewController->frequency];
    //[data writeToFile:path options:NSDataWritingAtomic error:&error];
    NSString *fileName = [NSString stringWithFormat:@"/Users/bryan/Documents/Xcode Projects/Tone Gen/audioFreq%@.txt",frequencyString];
    NSError * error = NULL;
    NSStringEncoding encoding;
    NSMutableString * content = [[NSMutableString alloc] initWithContentsOfFile: fileName usedEncoding: &encoding error: &error];
    
    if(content)
    {
        
        // Generate the samples
        for (UInt32 frame = 0; frame < inNumberFrames; frame++)
        {
            buffer[frame] = sin(theta) * amplitude;
            //NSLog(@"%f",buffer[frame]);
            
            if((frame / 500) ==1){
            
            NSString *str = [NSString stringWithFormat:@"%f", buffer[frame]];
            [content appendFormat: @"%@ ", str];
            
            //save content to the documents directory
            if(!viewController->allowRecording)
                {
                    BOOL success = [content writeToFile:fileName
                                             atomically:YES
                                               encoding:NSStringEncodingConversionAllowLossy
                                                  error:&error];
                
                    if(success == NO)
                    {
                        NSLog( @"couldn't write out file to %@, error is %@", fileName, [error localizedDescription]);
                    }
                }
            
            }
            
            theta += theta_increment;
            if (theta > 2.0 * M_PI)
            {
                theta -= 2.0 * M_PI;
            }
        }
    }
        else
        {
            //on the mobile form
            // Generate the samples
            for (UInt32 frame = 0; frame < inNumberFrames; frame++)
            {
                buffer[frame] = sin(theta) * amplitude;
                //NSLog(@"%f",buffer[frame]);
                
                if((frame / 500) ==1){
                    
                    //NSString *str = [NSString stringWithFormat:@"%f", buffer[frame]];
                    //[content appendFormat: @"%@ ", str];
                    
                    //save content to the documents directory
                    if(!viewController->allowRecording)
                    {
                       
                        
                    }
                    
                    theta += theta_increment;
                    if (theta > 2.0 * M_PI)
                    {
                        theta -= 2.0 * M_PI;
                    }
                }
            }

        }
	
	// Store the theta back in the view controller
	viewController->theta = theta;

	return noErr;
}

void ToneInterruptionListener(void *inClientData, UInt32 inInterruptionState)
{
	ToneGeneratorViewController *viewController =
		(ToneGeneratorViewController *)inClientData;
	
	[viewController stop];
}

@interface ToneGeneratorViewController()

@property (nonatomic, strong)   NSString *fileText;
@property (nonatomic, strong)   NSString *fileName2;
@property (nonatomic, strong)   NSMutableString *content2;
@property   NSInteger count;
@property (nonatomic, strong)   NSMutableString *contentMobile;

@end

@implementation ToneGeneratorViewController

@synthesize frequencySlider;
@synthesize playButton;
@synthesize frequencyLabel;




- (IBAction)sliderChanged:(UISlider *)slider
{
	frequency = slider.value;
	frequencyLabel.text = [NSString stringWithFormat:@"%4.1f Hz", frequency];
}

- (void)createToneUnit
{
	// Configure the search parameters to find the default playback output unit
	// (called the kAudioUnitSubType_RemoteIO on iOS but
	// kAudioUnitSubType_DefaultOutput on Mac OS X)
	AudioComponentDescription defaultOutputDescription;
	defaultOutputDescription.componentType = kAudioUnitType_Output;
	defaultOutputDescription.componentSubType = kAudioUnitSubType_RemoteIO;
	defaultOutputDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
	defaultOutputDescription.componentFlags = 0;
	defaultOutputDescription.componentFlagsMask = 0;
	
	// Get the default playback output unit
	AudioComponent defaultOutput = AudioComponentFindNext(NULL, &defaultOutputDescription);
	NSAssert(defaultOutput, @"Can't find default output");
	
	// Create a new unit based on this that we'll use for output
	OSErr err = AudioComponentInstanceNew(defaultOutput, &toneUnit);
	NSAssert1(toneUnit, @"Error creating unit: %hd", err);
	
	// Set our tone rendering function on the unit
	AURenderCallbackStruct input;
	input.inputProc = RenderTone;
	input.inputProcRefCon = self;
	err = AudioUnitSetProperty(toneUnit, 
		kAudioUnitProperty_SetRenderCallback, 
		kAudioUnitScope_Input,
		0, 
		&input, 
		sizeof(input));
	NSAssert1(err == noErr, @"Error setting callback: %hd", err);
	
	// Set the format to 32 bit, single channel, floating point, linear PCM
	const int four_bytes_per_float = 4;
	const int eight_bits_per_byte = 8;
	AudioStreamBasicDescription streamFormat;
	streamFormat.mSampleRate = sampleRate;
	streamFormat.mFormatID = kAudioFormatLinearPCM;
	streamFormat.mFormatFlags =
		kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
	streamFormat.mBytesPerPacket = four_bytes_per_float;
	streamFormat.mFramesPerPacket = 1;	
	streamFormat.mBytesPerFrame = four_bytes_per_float;		
	streamFormat.mChannelsPerFrame = 1;	
	streamFormat.mBitsPerChannel = four_bytes_per_float * eight_bits_per_byte;
	err = AudioUnitSetProperty (toneUnit,
		kAudioUnitProperty_StreamFormat,
		kAudioUnitScope_Input,
		0,
		&streamFormat,
		sizeof(AudioStreamBasicDescription));
	NSAssert1(err == noErr, @"Error setting stream format: %hd", err);
}

- (IBAction)togglePlay:(UIButton *)selectedButton
{
    NSString *frequencyString = [NSString stringWithFormat:@"%d", (int)frequency];
    NSString *fileName = [NSString stringWithFormat:@"/Users/bryan/Documents/Xcode Projects/Tone Gen/audioFreq%@.txt",frequencyString];
    [[NSFileManager defaultManager] createFileAtPath:fileName contents:nil attributes:nil];

    
//	if (toneUnit)
//	{
//		AudioOutputUnitStop(toneUnit);
//		AudioUnitUninitialize(toneUnit);
//		AudioComponentInstanceDispose(toneUnit);
//		toneUnit = nil;
//        
//        
//		[selectedButton setTitle:NSLocalizedString(@"Play", nil) forState:0];
//	}
//	else
//	{
//		[self createToneUnit];
//		
//		// Stop changing parameters on the unit
//		OSErr err = AudioUnitInitialize(toneUnit);
//		NSAssert1(err == noErr, @"Error initializing unit: %hd", err);
//		
//		// Start playback
//		err = AudioOutputUnitStart(toneUnit);
//		NSAssert1(err == noErr, @"Error starting unit: %hd", err);
//		
//		[selectedButton setTitle:NSLocalizedString(@"Stop", nil) forState:0];
//	}
    
    //just play the tone one time
    [self createToneUnit];
    OSErr err = AudioUnitInitialize(toneUnit);
    NSAssert1(err == noErr, @"Error initializing unit: %hd", err);
    //NSLog(@"%@",toneUnit);
    sleep(2);
    err = AudioOutputUnitStart(toneUnit);
    NSAssert1(err == noErr, @"Error starting unit: %hd", err);
    [NSThread sleepForTimeInterval:1.0f];//here is where we control how long the tone is for
    //NSLog(@"%@",toneUnit);
    AudioOutputUnitStop(toneUnit);
    AudioUnitUninitialize(toneUnit);
    AudioComponentInstanceDispose(toneUnit);
    toneUnit = nil;
    //NSLog(@"Done");
}

- (IBAction)toggleRecord:(UIButton *)selectedButton
{
    if (!allowRecording)
    {
        self.count++;
        [levelTimer invalidate];
        levelTimer = nil;
        [selectedButton setTitle:NSLocalizedString(@"Record", nil) forState:0];
    }
    else
    {
        [self createNewRecordOutput];
        //THIS is the limiting reagent on storage, is how fast we can write which is 0.1 milliseconds 0.0001s
        levelTimer = [NSTimer scheduledTimerWithTimeInterval: 0.0 target: self selector: @selector(levelTimerCallback:) userInfo: nil repeats: YES];
        [selectedButton setTitle:NSLocalizedString(@"Stop", nil) forState:0];
    }
    allowRecording = !allowRecording;
    
    
}

- (void)stop
{
	if (toneUnit)
	{
		[self togglePlay:playButton];
	}
}

- (void)viewDidLoad {
	[super viewDidLoad];
    self.count = 1;
    allowRecording = TRUE;
    //listener
    
    
    self->audioSession = [AVAudioSession sharedInstance];
    [self->audioSession setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:kAudioSessionProperty_OverrideCategoryMixWithOthers error:nil];
    [self->audioSession setActive:YES error:nil];
    AudioServicesPlaySystemSound(1008);//test
    NSString *tempDir = NSTemporaryDirectory();
    NSString *soundFilePath = [tempDir stringByAppendingPathComponent:@"sound.m4a"];
    
    NSURL *url = [NSURL fileURLWithPath:soundFilePath];
    NSLog(@"%@", url);

    //NSURL *url = [NSURL fileURLWithPath:@"/dev/null"];     //this worked for sim only

    
    NSDictionary *settings = [NSDictionary dictionaryWithObjectsAndKeys:
                              [NSNumber numberWithFloat: 44100.0],                 AVSampleRateKey,
                              [NSNumber numberWithInt: kAudioFormatAppleLossless], AVFormatIDKey,
                              [NSNumber numberWithInt: 1],                         AVNumberOfChannelsKey,
                              [NSNumber numberWithInt: AVAudioQualityMax],         AVEncoderAudioQualityKey,
                              nil];
    
    NSError *error;
    
    recorder = [[AVAudioRecorder alloc] initWithURL:url settings:settings error:&error];
    
    if (recorder) {
        [recorder prepareToRecord];
        recorder.meteringEnabled = YES;
        [recorder record];
//        levelTimer = [NSTimer scheduledTimerWithTimeInterval: 0.03 target: self selector: @selector(levelTimerCallback:) userInfo: nil repeats: YES];
    }
    
    [self sliderChanged:frequencySlider];
    sampleRate = 44100;
    
    //audioSession set
    //this code breaks my stuff, but then I cant play anything
//    OSStatus result = AudioSessionInitialize(NULL, NULL, ToneInterruptionListener, self);
//    if (result == kAudioSessionNoError)
//    {
//        UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;//kAudioSessionCategory_PlayAndRecord;//
//        AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(sessionCategory), &sessionCategory);
//    }
//    AudioSessionSetActive(true);
    
    
    
    
    //[self createNewRecordOutput];
//    self.fileName2 = [NSString stringWithFormat:@"/Users/bryan/Documents/Xcode Projects/Tone Gen/recordAudioFreqOutput%ld.txt",(long)self.count];
//    [[NSFileManager defaultManager] createFileAtPath:self.fileName2 contents:nil attributes:nil];
//    NSStringEncoding encoding;
//    self.content2 = [[NSMutableString alloc] initWithContentsOfFile: self.fileName2 usedEncoding: &encoding error: nil];
    
    
}


-(void)createNewRecordOutput{
    self.fileName2 = [NSString stringWithFormat:@"/Users/bryan/Documents/Xcode Projects/Tone Gen/recordAudioFreqOutput%ld.txt",(long)self.count];
    [[NSFileManager defaultManager] createFileAtPath:self.fileName2 contents:nil attributes:nil];
    NSStringEncoding encoding;
    self.content2 = [[NSMutableString alloc] initWithContentsOfFile: self.fileName2 usedEncoding: &encoding error: nil];
    self.contentMobile = [[NSMutableString alloc]  init];
    //self.contentMobile = [[NSMutableString alloc] initWithContentsOfURL:<#(NSURL *)#> encoding:&encoding error:nil];
}

- (void)viewDidUnload {
	self.frequencyLabel = nil;
	self.playButton = nil;
	self.frequencySlider = nil;

	AudioSessionSetActive(false);
}

- (void)levelTimerCallback:(NSTimer *)timer {
    [recorder updateMeters];
    
    
    //The noise/sound of someone blowing into the mic is made up of low-frequency sounds. We’ll use a low pass filter to reduce the high frequency sounds coming in on the mic; when the level of the filtered signal spikes we’ll know someone’s blowing into the mic.
    const double ALPHA = 0.05;
    double peakPowerForChannel = pow(10, (0.05 * [recorder peakPowerForChannel:0]));
    lowPassResults = ALPHA * peakPowerForChannel + (1.0 - ALPHA) * lowPassResults;
    
    //if(!allowRecording){
    NSString *str = [NSString stringWithFormat:@"%f", lowPassResults];
    //[self.content2 appendFormat: @"%@ ", str];
    [self.contentMobile appendFormat:@"%@ ",str];
    //save content to the documents directory
    //[self.content2 writeToFile:self.fileName2
    //                          atomically:YES
    //                            encoding:NSStringEncodingConversionAllowLossy
    //                               error:nil];
    
   
    //NSLog(@"%f",lowPassResults);
    //}
    
}

- (void)dealloc {
    [levelTimer release];
    [recorder release];
    [super dealloc];
}

- (IBAction)exportButton:(UIButton *)selectedButton
{
    UIActionSheet *actionSheet = [[[UIActionSheet alloc]
                                   initWithTitle:@""
                                   delegate:self
                                   cancelButtonTitle:@"Cancel"
                                   destructiveButtonTitle:nil
                                   otherButtonTitles:@"Export via Email", nil] autorelease];
    [actionSheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    
    if (buttonIndex == actionSheet.firstOtherButtonIndex + 0) {

        [self displayComposerSheet];
    }
    
}

-(void)displayComposerSheet
{
    MFMailComposeViewController *picker = [[MFMailComposeViewController alloc] init];
    picker.mailComposeDelegate = self;
    [picker setSubject:@"Sound data!"];
    
    // Set up recipients
     NSArray *toRecipients = [NSArray arrayWithObject:@"bid5098@psu.edu"];
    // NSArray *ccRecipients = [NSArray arrayWithObjects:@"second@example.com", @"third@example.com", nil];
    // NSArray *bccRecipients = [NSArray arrayWithObject:@"fourth@example.com"];
    
     [picker setToRecipients:toRecipients];
    // [picker setCcRecipients:ccRecipients];
    // [picker setBccRecipients:bccRecipients];
    
    // Attach an image to the email
    //UIImage *coolImage = ...;
    NSData *myData = [self.contentMobile dataUsingEncoding:NSUTF8StringEncoding];
    //NSData *myData = UIImagePNGRepresentation(coolImage);
    [picker addAttachmentData:myData mimeType:@"text/csv" fileName:@"output.txt"];
    
    // Fill out the email body text
    NSString *emailBody = @"My cool stuff is attached";
    [picker setMessageBody:self.content2 isHTML:NO];
    [self presentModalViewController:picker animated:YES];
    
    [picker release];
}

- (void)mailComposeController:(MFMailComposeViewController *)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError *)error {
    // Notifies users about errors associated with the interface
    switch (result)
    {
        case MFMailComposeResultCancelled:
        NSLog(@"Result: canceled");
        break;
        case MFMailComposeResultSaved:
        NSLog(@"Result: saved");
        break;
        case MFMailComposeResultSent:
        NSLog(@"Result: sent");
        break;
        case MFMailComposeResultFailed:
        NSLog(@"Result: failed");
        break;
        default:
        NSLog(@"Result: not sent");
        break;
    }
    [self dismissModalViewControllerAnimated:YES];
}

@end
