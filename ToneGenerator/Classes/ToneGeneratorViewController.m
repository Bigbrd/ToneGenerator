//
//  ToneGeneratorViewController.m
//  ToneGenerator
//
//
#define pauseTime 2
#define sleepTime 1.0f

#import "ToneGeneratorViewController.h"
#import <AudioToolbox/AudioToolbox.h>


//this method creates the tone that is played
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
    
    
    //on the mobile form
    // Generate the samples
    for (UInt32 frame = 0; frame < inNumberFrames; frame++)
    {
        buffer[frame] = sin(theta) * amplitude;
        
        if((frame / 500) ==1){
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
    //just play the tone one time
    [self createToneUnit];
    OSErr err = AudioUnitInitialize(toneUnit);
    NSAssert1(err == noErr, @"Error initializing unit: %hd", err);
    sleep(pauseTime);
    err = AudioOutputUnitStart(toneUnit);
    NSAssert1(err == noErr, @"Error starting unit: %hd", err);
    
    [NSThread sleepForTimeInterval:sleepTime];//here is where we control how long the tone is for
    
    //end the playing of the tone
    AudioOutputUnitStop(toneUnit);
    AudioUnitUninitialize(toneUnit);
    AudioComponentInstanceDispose(toneUnit);
    toneUnit = nil;
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
    }
    
    [self sliderChanged:frequencySlider];
    sampleRate = 44100;
    
}


-(void)createNewRecordOutput{
    self.contentMobile = [[NSMutableString alloc]  init];
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
    
    //append the string of the recorded audio
    NSString *str = [NSString stringWithFormat:@"%f", lowPassResults];
    [self.contentMobile appendFormat:@"%@ ",str];
    
}

- (void)dealloc {
    [levelTimer release];
    [recorder release];
    [super dealloc];
}

#pragma mark - Email Composition Methods

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
    NSArray *toRecipients = [NSArray arrayWithObject:@"example@example.com"];
    // NSArray *ccRecipients = [NSArray arrayWithObjects:@"second@example.com", @"third@example.com", nil];
    // NSArray *bccRecipients = [NSArray arrayWithObject:@"fourth@example.com"];
    
     [picker setToRecipients:toRecipients];
    // [picker setCcRecipients:ccRecipients];
    // [picker setBccRecipients:bccRecipients];
    
    // Attach the data to the email
    NSData *myData = [self.contentMobile dataUsingEncoding:NSUTF8StringEncoding];
    [picker addAttachmentData:myData mimeType:@"text/csv" fileName:@"output.txt"];
    
    //[picker setMessageBody:self.content2 isHTML:NO];
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
