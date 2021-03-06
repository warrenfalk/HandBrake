/* HBAudioController.h

 This file is part of the HandBrake source code.
 Homepage: <http://handbrake.fr/>.
 It may be used under the terms of the GNU General Public License. */

#import <Cocoa/Cocoa.h>

@class HBAudio;

/**
 *  HBAudioController
 */
@interface HBAudioController : NSViewController

@property (nonatomic, readwrite, assign) HBAudio *audio;

@end
