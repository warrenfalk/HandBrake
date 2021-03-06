/*  HBVideo.m $

 This file is part of the HandBrake source code.
 Homepage: <http://handbrake.fr/>.
 It may be used under the terms of the GNU General Public License. */

#import "HBVideo.h"
#import "HBJob.h"
#import "NSCodingMacro.h"
#include "hb.h"

NSString * const HBVideoChangedNotification = @"HBVideoChangedNotification";

@interface HBVideo ()

@property (nonatomic, readwrite) double qualityMinValue;
@property (nonatomic, readwrite) double qualityMaxValue;

@property (nonatomic, readwrite) NSUInteger mediumPresetIndex;

@property (nonatomic, readwrite, getter=areNotificationsEnabled) BOOL notificationsEnabled;

@end

@implementation HBVideo

- (instancetype)initWithJob:(HBJob *)job;
{
    self = [super init];
    if (self) {
        _encoder = HB_VCODEC_X264;
        _avgBitrate = 1000;
        _quality = 18.0;
        _qualityMaxValue = 51.0f;
        _job = job;

        _preset = @"medium";
        _tune = @"";
        _profile = @"auto";
        _level = @"auto";

        [self updateQualityBounds];

        _notificationsEnabled = YES;
    }
    return self;
}

- (void)postChangedNotification
{
    if (self.areNotificationsEnabled)
    {
        [[NSNotificationCenter defaultCenter] postNotification: [NSNotification notificationWithName:HBVideoChangedNotification
                                                                                              object:self
                                                                                            userInfo:nil]];
    }
}

#pragma mark - Setters

/**
 *  Updates the min/max quality values
 */
- (void)updateQualityBounds
{
    // Get the current slider maxValue to check for a change in slider scale
    // later so that we can choose a new similar value on the new slider scale
    double previousMaxValue             = self.qualityMaxValue;
    double previousPercentOfSliderScale = (self.quality / (self.qualityMaxValue - self.qualityMinValue + 1));

    int direction;
    float minValue, maxValue, granularity;
    hb_video_quality_get_limits(self.encoder,
                                &minValue, &maxValue, &granularity, &direction);

    self.qualityMinValue = minValue;
    self.qualityMaxValue = maxValue;

    // check to see if we have changed slider scales
    if (previousMaxValue != maxValue)
    {
        // if so, convert the old setting to the new scale as close as possible
        // based on percentages
        self.quality = floor((maxValue - minValue + 1.) * (previousPercentOfSliderScale));
    }
}

- (void)setEncoder:(int)encoder
{
    _encoder = encoder;
    [self updateQualityBounds];
    [self validatePresetsSettings];
    [self validateAdvancedOptions];

    [self postChangedNotification];
}

- (void)setQualityType:(int)qualityType
{
    _qualityType = qualityType;
    [self postChangedNotification];
}

- (void)setAvgBitrate:(int)avgBitrate
{
    _avgBitrate = avgBitrate;
    [self postChangedNotification];
}

- (void)setQuality:(double)quality
{
    _quality = quality;
    [self postChangedNotification];
}

- (void)setFrameRate:(int)frameRate
{
    _frameRate = frameRate;
    [self postChangedNotification];
}

- (void)setFrameRateMode:(int)frameRateMode
{
    _frameRateMode = frameRateMode;
    [self postChangedNotification];
}

- (void)setTwoPass:(BOOL)twoPass
{
    _twoPass = twoPass;
    [self postChangedNotification];
}

- (void)setTurboTwoPass:(BOOL)turboTwoPass
{
    _turboTwoPass = turboTwoPass;
    [self postChangedNotification];
}

- (void)containerChanged
{
    BOOL encoderSupported = NO;

    for (const hb_encoder_t *video_encoder = hb_video_encoder_get_next(NULL);
         video_encoder != NULL;
         video_encoder  = hb_video_encoder_get_next(video_encoder))
    {
        if (video_encoder->muxers & self.job.container)
        {
            if (video_encoder->codec == self.encoder)
            {
                encoderSupported = YES;
            }
        }
    }

    if (!encoderSupported)
    {
        self.encoder = HB_VCODEC_X264;
    }
}

- (void)setPreset:(NSString *)preset
{
    [_preset autorelease];
    _preset = [preset copy];
    [self postChangedNotification];
}

- (void)setTune:(NSString *)tune
{
    [_tune autorelease];

    if (![tune isEqualToString:@"none"])
    {
        _tune = [tune copy];
    }
    else
    {
        _tune = @"";
    }

    [self postChangedNotification];
}

- (void)setProfile:(NSString *)profile
{
    [_profile autorelease];
    _profile = [profile copy];
    [self postChangedNotification];
}

- (void)setLevel:(NSString *)level
{
    [_level autorelease];
    _level = [level copy];
    [self postChangedNotification];
}

- (void)setVideoOptionExtra:(NSString *)videoOptionExtra
{
    [_videoOptionExtra autorelease];
    if (videoOptionExtra != nil)
    {
        _videoOptionExtra = [videoOptionExtra copy];
    }
    else
    {
        _videoOptionExtra = @"";
    }
    [self postChangedNotification];
}

- (void)setFastDecode:(BOOL)fastDecode
{
    _fastDecode = fastDecode;
    [self postChangedNotification];
}

- (void)validatePresetsSettings
{
    NSArray *presets = self.presets;
    if (presets.count && ![presets containsObject:self.preset]) {
        self.preset = presets[self.mediumPresetIndex];
    }

    NSArray *tunes = self.tunes;
    if (tunes.count && ![tunes containsObject:self.tune]) {
        self.tune = tunes.firstObject;
    }

    NSArray *profiles = self.profiles;
    if (profiles.count && ![profiles containsObject:self.profile]) {
        self.profile = profiles.firstObject;
    }

    NSArray *levels = self.levels;
    if (levels.count && ![levels containsObject:self.level]) {
        self.level = levels.firstObject;
    }
}

- (void)validateAdvancedOptions
{
    if (self.encoder != HB_VCODEC_H264_MASK)
    {
        self.advancedOptions = NO;
    }
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
    NSSet *retval = nil;

    // Tell KVO to reload the presets settings
    // after a change to the encoder.
    if ([key isEqualToString:@"presets"] ||
        [key isEqualToString:@"tunes"] ||
        [key isEqualToString:@"profiles"] ||
        [key isEqualToString:@"levels"])
    {
        retval = [NSSet setWithObjects:@"encoder", nil];
    }

    // Tell KVO to reload the x264 unparse string
    // after values changes.
    if ([key isEqualToString:@"unparseOptions"])
    {
        retval = [NSSet setWithObjects:@"encoder", @"preset", @"tune", @"profile", @"level",
                  @"videoOptionExtra", @"fastDecode", @"job.picture.width", @"job.picture.height", nil];
    }

    if ([key isEqualToString:@"encoders"])
    {
        retval = [NSSet setWithObjects:@"job.container", nil];
    }

    if ([key isEqualToString:@"fastDecodeSupported"] ||
        [key isEqualToString:@"turboTwoPassSupported"])
    {
        retval = [NSSet setWithObjects:@"encoder", nil];
    }

    return retval;
}

- (void)setNilValueForKey:(NSString *)key
{
    [self setValue:@0 forKey:key];
}

#pragma mark -

- (NSArray *)presets
{
    NSMutableArray *temp = [NSMutableArray array];

    const char * const *presets = hb_video_encoder_get_presets(self.encoder);
    for (int i = 0; presets != NULL && presets[i] != NULL; i++)
    {
        [temp addObject:@(presets[i])];
        if (!strcasecmp(presets[i], "medium"))
        {
            self.mediumPresetIndex = i;
        }
    }

    return [[temp copy] autorelease];
}

- (NSArray *)tunes
{
    NSMutableArray *temp = [NSMutableArray array];

    [temp addObject:@"none"];

    const char * const *tunes = hb_video_encoder_get_tunes(self.encoder);

    for (int i = 0; tunes != NULL && tunes[i] != NULL; i++)
    {
        // we filter out "fastdecode" as we have a dedicated checkbox for it
        if (strcasecmp(tunes[i], "fastdecode") != 0)
        {
            [temp addObject:@(tunes[i])];
        }
    }

    return [[temp copy] autorelease];
}

- (NSArray *)profiles
{
    NSMutableArray *temp = [NSMutableArray array];

    const char * const *profiles = hb_video_encoder_get_profiles(self.encoder);
    for (int i = 0; profiles != NULL && profiles[i] != NULL; i++)
    {
        [temp addObject:@(profiles[i])];
    }

    return [[temp copy] autorelease];
}

- (NSArray *)levels
{
    NSMutableArray *temp = [NSMutableArray array];

    const char * const *levels = hb_video_encoder_get_levels(self.encoder);
    for (int i = 0; levels != NULL && levels[i] != NULL; i++)
    {
        [temp addObject:@(levels[i])];
    }
    if (!temp.count)
    {
        [temp addObject:@"auto"];
    }

    return [[temp copy] autorelease];
}

#pragma mark - NSCopying

- (instancetype)copyWithZone:(NSZone *)zone
{
    HBVideo *copy = [[[self class] alloc] init];

    if (copy)
    {
        copy->_encoder = _encoder;

        copy->_qualityType = _qualityType;
        copy->_avgBitrate = _avgBitrate;
        copy->_quality = _quality;

        copy->_qualityMinValue = _qualityMinValue;
        copy->_qualityMaxValue = _qualityMaxValue;

        copy->_frameRate = _frameRate;
        copy->_frameRateMode = _frameRateMode;

        copy->_twoPass = _twoPass;
        copy->_turboTwoPass = _turboTwoPass;

        copy->_advancedOptions = _advancedOptions;
        copy->_preset = [_preset copy];
        copy->_tune = [_tune copy];
        copy->_profile = [_profile copy];
        copy->_level = [_level copy];
        copy->_videoOptionExtra = [_videoOptionExtra copy];
        copy->_fastDecode = _fastDecode;

        copy->_notificationsEnabled = _notificationsEnabled;
    }

    return copy;
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInt:1 forKey:@"HBVideoVersion"];

    encodeInt(_encoder);

    encodeInt(_qualityType);
    encodeInt(_avgBitrate);
    encodeDouble(_quality);

    encodeDouble(_qualityMinValue);
    encodeDouble(_qualityMaxValue);

    encodeInt(_frameRate);
    encodeInt(_frameRateMode);

    encodeBool(_twoPass);
    encodeBool(_turboTwoPass);

    encodeBool(_advancedOptions);
    encodeObject(_preset);
    encodeObject(_tune);
    encodeObject(_profile);
    encodeObject(_level);

    encodeObject(_videoOptionExtra);

    encodeBool(_fastDecode);
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];

    decodeInt(_encoder);

    decodeInt(_qualityType);
    decodeInt(_avgBitrate);
    decodeDouble(_quality);

    decodeDouble(_qualityMinValue);
    decodeDouble(_qualityMaxValue);

    decodeInt(_frameRate);
    decodeInt(_frameRateMode);

    decodeBool(_twoPass);
    decodeBool(_turboTwoPass);

    decodeBool(_advancedOptions);
    decodeObject(_preset);
    decodeObject(_tune);
    decodeObject(_profile);
    decodeObject(_level);

    decodeObject(_videoOptionExtra);

    decodeBool(_fastDecode);

    _notificationsEnabled = YES;

    return self;
}

#pragma mark - Various conversion methods from dict/preset/queue/etc

/**
 *  Returns a string minus the fastdecode string.
 */
- (NSString *)stripFastDecodeFromString:(NSString *)tune
{
    // filter out fastdecode
    tune = [tune stringByReplacingOccurrencesOfString:@"," withString:@""];
    tune = [tune stringByReplacingOccurrencesOfString:@"fastdecode" withString:@""];

    return tune;
}

/**
 *  Retuns the tune string plus the fastdecode option (if enabled)
 */
- (NSString *)completeTune
{
    NSMutableString *string = [[NSMutableString alloc] init];

    if (self.tune)
    {
        [string appendString:self.tune];
    }

    if (self.fastDecode)
    {
        if (string.length)
        {
            [string appendString:@","];
        }

        [string appendString:@"fastdecode"];
    }

    return [string autorelease];
}

- (void)applyPreset:(NSDictionary *)preset
{
    self.notificationsEnabled = NO;

    // map legacy encoder names via libhb.
    const char *strValue = hb_video_encoder_sanitize_name([preset[@"VideoEncoder"] UTF8String]);
    self.encoder = hb_video_encoder_get_from_name(strValue);

    if (self.encoder == HB_VCODEC_X264 || self.encoder == HB_VCODEC_X265)
    {
        if (self.encoder == HB_VCODEC_X264 &&
            (!preset[@"x264UseAdvancedOptions"] ||
             [preset[@"x264UseAdvancedOptions"] intValue]))
        {
            // preset does not use the x264 preset system, reset the widgets.
            self.preset = @"medium";
            self.tune = @"";
            self.profile = @"auto";
            self.level = @"auto";
            self.fastDecode = NO;

            // x264UseAdvancedOptions is not set (legacy preset)
            // or set to 1 (enabled), so we use the old advanced panel.
            if (preset[@"x264Option"])
            {
                // we set the advanced options string here if applicable.
                self.videoOptionExtra = preset[@"x264Option"];
                self.advancedOptions = YES;
            }
            else
            {
                self.videoOptionExtra = nil;
            }
        }
        else
        {
            // x264UseAdvancedOptions is set to 0 (disabled),
            // so we use the new preset system and
            // disable the advanced panel
            self.advancedOptions = NO;

            if (preset[@"x264Preset"])
            {
                // Read the old x264 preset keys
                self.preset = preset[@"x264Preset"];
                self.tune   = preset[@"x264Tune"];
                self.videoOptionExtra = preset[@"x264OptionExtra"];
                self.profile = preset[@"h264Profile"];
                self.level   = preset[@"h264Level"];
            }
            else
            {
                // Read the new preset keys (0.10)
                self.preset = preset[@"VideoPreset"];
                self.tune   = preset[@"VideoTune"];
                self.videoOptionExtra = preset[@"VideoOptionExtra"];
                self.profile = preset[@"VideoProfile"];
                self.level   = preset[@"VideoLevel"];
            }

            if ([self.tune rangeOfString:@"fastdecode"].location != NSNotFound)
            {
                self.fastDecode = YES;;
            }
            else
            {
                self.fastDecode = NO;
            }

            self.tune = [self stripFastDecodeFromString:self.tune];
        }
    }
    else
    {
        if (preset[@"lavcOption"])
        {
            // Load the old format
            self.videoOptionExtra = preset[@"lavcOption"];
        }
        else
        {
            self.videoOptionExtra = preset[@"VideoOptionExtra"];
        }
    }

    int qualityType = [preset[@"VideoQualityType"] intValue] - 1;
    /* Note since the removal of Target Size encoding, the possible values for VideoQuality type are 0 - 1.
     * Therefore any preset that uses the old 2 for Constant Quality would now use 1 since there is one less index
     * for the fVidQualityMatrix. It should also be noted that any preset that used the deprecated Target Size
     * setting of 0 would set us to 0 or ABR since ABR is now tagged 0. Fortunately this does not affect any built-in
     * presets since they all use Constant Quality or Average Bitrate.*/
    if (qualityType == -1)
    {
        qualityType = 0;
    }
    self.qualityType = qualityType;

    self.avgBitrate = [preset[@"VideoAvgBitrate"] intValue];
    self.quality = [preset[@"VideoQualitySlider"] floatValue];

    // Video framerate
    if ([preset[@"VideoFramerate"] isEqualToString:@"Same as source"])
    {
        // Now set the Video Frame Rate Mode to either vfr or cfr according to the preset.
        if (!preset[@"VideoFramerateMode"] ||
            [preset[@"VideoFramerateMode"] isEqualToString:@"vfr"])
        {
            self.frameRateMode = 0; // we want vfr
        }
        else
        {
            self.frameRateMode = 1; // we want cfr
        }
    }
    else
    {
        // Now set the Video Frame Rate Mode to either pfr or cfr according to the preset.
        if ([preset[@"VideoFramerateMode"] isEqualToString:@"pfr"] ||
            [preset[@"VideoFrameratePFR"]  intValue] == 1)
        {
            self.frameRateMode = 0; // we want pfr
        }
        else
        {
            self.frameRateMode = 1; // we want cfr
        }
    }
    // map legacy names via libhb.
    int intValue = hb_video_framerate_get_from_name([preset[@"VideoFramerate"] UTF8String]);
    if (intValue == -1)
    {
        intValue = 0;
    }
    self.frameRate = intValue;

    // 2 Pass Encoding.
    self.twoPass = [preset[@"VideoTwoPass"] boolValue];

    // Turbo 1st pass for 2 Pass Encoding.
    self.turboTwoPass = [preset[@"VideoTurboTwoPass"] boolValue];

    self.notificationsEnabled = YES;
}

- (void)writeToPreset:(NSMutableDictionary *)preset
{
    preset[@"VideoEncoder"] = @(hb_video_encoder_get_name(self.encoder));

    // x264 Options, this will either be advanced panel or the video tabs x264 presets panel with modded option string
    if (self.advancedOptions)
    {
        // use the old advanced panel.
        preset[@"x264UseAdvancedOptions"] = @1;
        preset[@"x264Option"] = self.videoOptionExtra;
    }
    else if (self.encoder == HB_VCODEC_X264 || self.encoder == HB_VCODEC_X265)
    {
        // use the new preset system.
        preset[@"x264UseAdvancedOptions"] = @0;
        preset[@"VideoPreset"]      = self.preset;
        preset[@"VideoTune"]        = [self completeTune];
        preset[@"VideoOptionExtra"] = self.videoOptionExtra;
        preset[@"VideoProfile"]     = self.profile;
        preset[@"VideoLevel"]       = self.level;
    }
    else
    {
        // FFmpeg (lavc) Option String
        preset[@"VideoOptionExtra"] = self.videoOptionExtra;
    }

    /* though there are actually only 0 - 1 types available in the ui we need to map to the old 0 - 2
     * set of indexes from when we had 0 == Target , 1 == Abr and 2 == Constant Quality for presets
     * to take care of any legacy presets. */
    preset[@"VideoQualityType"] = @(self.qualityType + 1);
    preset[@"VideoAvgBitrate"] = @(self.avgBitrate);
    preset[@"VideoQualitySlider"] = @(self.quality);

    /* Video framerate and framerate mode */
    if (self.frameRateMode == 1)
    {
        preset[@"VideoFramerateMode"] = @"cfr";
    }
    if (self.frameRate == 0) // Same as source is selected
    {
        preset[@"VideoFramerate"] = @"Same as source";

        if (self.frameRateMode == 0)
        {
            preset[@"VideoFramerateMode"] = @"vfr";
        }
    }
    else // translate the rate (selected item's tag) to the official libhb name
    {
        preset[@"VideoFramerate"] = [NSString stringWithFormat:@"%s",
                                     hb_video_framerate_get_name((int)self.frameRate)];

        if (self.frameRateMode == 0)
        {
            preset[@"VideoFramerateMode"] = @"pfr";
        }
    }

    preset[@"VideoTwoPass"] = @(self.twoPass);
    preset[@"VideoTurboTwoPass"] = @(self.turboTwoPass);
}

@end
