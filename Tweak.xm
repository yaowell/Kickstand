#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static void KSLog(NSString *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);

    NSString *line = [NSString stringWithFormat:@"[Kickstand] %@\n", s];
    NSString *path = @"/var/mobile/Documents/Kickstand.log";

    NSFileHandle *f = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!f) {
        [line writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    } else {
        [f seekToEndOfFile];
        [f writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [f closeFile];
    }
}

%hook SBCoverSheetPrimarySlidingViewController

- (void)grabberTongueWillPresent:(id)gesture {
    KSLog(@"WILL_PRESENT gesture=%@", NSStringFromClass([gesture class]));
    %orig;
}

- (void)grabberTongueUpdatedPulling:(id)tongue
                       withDistance:(double)distance
                        andVelocity:(double)velocity
                         andGesture:(id)gesture {
    KSLog(@"UPDATED distance=%.1f velocity=%.1f gesture=%@",
          distance,
          velocity,
          NSStringFromClass([gesture class]));
    %orig;
}

- (void)grabberTongueEndedPulling:(id)tongue
                     withDistance:(double)distance
                      andVelocity:(double)velocity
                       andGesture:(id)gesture {
    KSLog(@"ENDED distance=%.1f velocity=%.1f gesture=%@",
          distance,
          velocity,
          NSStringFromClass([gesture class]));
    %orig;
}

- (void)grabberTongueDidDismiss {
    KSLog(@"DID_DISMISS");
    %orig;
}

- (void)grabberTongueCanceledPulling:(id)tongue
                        withDistance:(double)distance
                         andVelocity:(double)velocity
                          andGesture:(id)gesture {
    KSLog(@"CANCELED distance=%.1f velocity=%.1f gesture=%@",
          distance,
          velocity,
          NSStringFromClass([gesture class]));
    %orig;
}

%end