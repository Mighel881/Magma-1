#import "Magma.h"
#import "include/UIColor.h"

NSMutableDictionary *prefs, *defaultPrefs;

%hook CCUIRoundButton
-(void)layoutSubviews {
	%orig;

	UIViewController *controller = [self _viewControllerForAncestor];
	UIView *backgroundView = self.selectedStateBackgroundView;

	NSString *toggleColor = nil;
	if ([controller isMemberOfClass:%c(CCUIConnectivityAirDropViewController)]) {
		toggleColor = getValue(@"toggleAirDrop");
	} else if ([controller isMemberOfClass:%c(CCUIConnectivityAirplaneViewController)]) {
		toggleColor = getValue(@"toggleAirplaneMode");
	} else if ([controller isMemberOfClass:%c(CCUIConnectivityBluetoothViewController)]) {
		toggleColor = getValue(@"toggleBluetooth");
	} else if ([controller isMemberOfClass:%c(CCUIConnectivityCellularDataViewController)]) {
		toggleColor = getValue(@"toggleCellularData");
	} else if ([controller isMemberOfClass:%c(CCUIConnectivityHotspotViewController)]) {
		toggleColor = getValue(@"toggleHotspot");
	} else if ([controller isMemberOfClass:%c(CCUIConnectivityWifiViewController)]) {
		toggleColor = getValue(@"toggleWiFi");
	}

	if (toggleColor == nil) return;

	[backgroundView setBackgroundColor:[UIColor RGBAColorFromHexString:toggleColor]];
}
%end

%hook CCUIButtonModuleView
-(void)setGlyphState:(NSString *)arg1 {
	%orig;
	[self colorButton];
}

-(void)_updateForStateChange {
	%orig;

	// Workaround for the flashlight because it doesn't respond to setGlyphState
	UIViewController *controller = [self _viewControllerForAncestor];
	NSString *description = [controller description];
	if ([description containsString:@"Flashlight"]) {
		[self colorButton];
	}
}

%new
-(void)colorButton {
	UIViewController *controller = [self _viewControllerForAncestor];

	NSString *description = [controller description];
	if ([controller isMemberOfClass:%c(CCUIToggleViewController)]) {
		CCUIToggleModule *module = ((CCUIToggleViewController *)controller).module;
		description = [module description];
	}

	NSString *toggleColor = nil;
	if ([description containsString:@"OrientationLock"]) {
		toggleColor = getValue(@"glyphRotationLock");
	} else if ([description containsString:@"DND"]) {
		toggleColor = getValue(@"glyphDoNotDisturb");
	} else if ([description containsString:@"LowPower"]) {
		toggleColor = getValue(@"glyphLowPowerMode");
	} else if ([description containsString:@"RPControlCenter"]) {
		toggleColor = getValue(@"glyphRecording");
	} else if ([description containsString:@"Timer"]) {
		toggleColor = getValue(@"glyphTimer");
	} else if ([description containsString:@"LocationModule"]) {
		toggleColor = getValue(@"glyphLocation");
	} else if ([description containsString:@"Flashlight"]) {
		toggleColor = getValue(@"glyphFlashlight");
	} else if ([description containsString:@"CarMode"]) {
		toggleColor = getValue(@"glyphCarMode");
	} else if ([description containsString:@"AirPlayMirroring"]) {
		toggleColor = getValue(@"glyphAirPlay");
	} else if ([description containsString:@"Mute"]) {
		// Fix inactive color because the same shape is used for on/off state
		toggleColor = [self.glyphState isEqual:@"ringer"] ? @"#FFFFFF:1.00" : getValue(@"glyphMute");
	} else if ([description containsString:@"VPN"]) {
		toggleColor = getValue(@"glyphVPN");
	}

	if (toggleColor == nil) return;

	colorLayers(self.layer.sublayers, [[UIColor RGBAColorFromHexString:toggleColor] CGColor]);

	for (UIView* subview in controller.view.allSubviews) {
		if ([subview isMemberOfClass:%c(UILabel)]) {
			colorLabel((UILabel *)subview, [UIColor RGBAColorFromHexString:toggleColor]);
		}
	}

}
%end

%hook CCUIModuleSliderView
-(void)didMoveToWindow {
	%orig;

	// On iOS 12 we could just hook an iVar to get the backdropView, on iOS 11 this is the only way
	for (UIView *subview in self.subviews) {
		if (![subview isMemberOfClass:%c(UIView)]) continue;
		for (_MTBackdropView *backdropView in subview.allSubviews) {
			if (![backdropView isMemberOfClass:%c(_MTBackdropView)]) continue;

			HBLogDebug(@"I GOT CALLED");

			// _MTBackdropView* backdropView = MSHookIvar<_MTBackdropView *>(matView, "_backdropView");

			UIViewController *controller = [self _viewControllerForAncestor];
			NSString *sliderColor = nil;

			if ([[controller description] containsString:@"Display"]) {
				sliderColor = getValue(@"sliderBrightness");
			} else if ([[controller description] containsString:@"Audio"]) {
				sliderColor = getValue(@"sliderVolume");
			}

			if (sliderColor == nil) return;

			backdropView.backgroundColor = [UIColor RGBAColorFromHexString:sliderColor];
			colorLayers(self.layer.sublayers, [[UIColor RGBAColorFromHexString:sliderColor] CGColor]);

			if (![sliderColor containsString:@":0.00"]) {
				backdropView.brightness = 0;
				backdropView.colorAddColor = [UIColor clearColor];
			} else {
				backdropView.brightness = 0.52;
				backdropView.colorAddColor = [UIColor colorWithRed:1.00 green:1.00 blue:1.00 alpha:0.25];
			}

		}
	}

}
%end

static BOOL isNotAColor(CGColorRef cgColor) {
	if (cgColor == nil) return YES;

	// Monochrome color
	if (CGColorGetNumberOfComponents(cgColor) <= 3) return YES;

	// There is probably a better way to do this, but it works for now
	const CGFloat *components = CGColorGetComponents(cgColor);
	NSString *color = [NSString stringWithFormat:@"%f,%f,%f", components[0], components[1], components[2]];
	NSString *white = [NSString stringWithFormat:@"%f,%f,%f", 1.0, 1.0, 1.0];
	NSString *black = [NSString stringWithFormat:@"%f,%f,%f", 0.0, 0.0, 0.0];

	return ([color isEqual:black] || [color isEqual:white] || components[3] == 0);
}

static void colorLabel(UILabel *label, UIColor *color) {
	UIColor *labelColor = label.textColor;
	if (!isNotAColor([labelColor CGColor])) {
		label.textColor = color;
	}
}

static void colorLayers(NSArray *layers, CGColorRef color) {
	for (CALayer *sublayer in layers) {
		if ([sublayer isMemberOfClass:%c(CAShapeLayer)]) {
			CGColorRef fillColor = ((CAShapeLayer *)sublayer).fillColor;
			if (!isNotAColor(fillColor)) {
				((CAShapeLayer *)sublayer).fillColor = color;
			}
		} else {
			CGColorRef backgroundColor = sublayer.backgroundColor;
			if (!isNotAColor(backgroundColor)) {
				sublayer.backgroundColor = color;
			}

			CGColorRef borderColor = sublayer.borderColor;
			if (!isNotAColor(borderColor)) {
				sublayer.borderColor = color;
			}

			CGColorRef contentColor = sublayer.contentsMultiplyColor;
			if (!isNotAColor(contentColor)) {
				sublayer.contentsMultiplyColor = color;
			}
		}

		colorLayers(sublayer.sublayers, color);
	}
}

// ----- PREFERENCE HANDLING ----- //

static BOOL getBool(NSString *key) {
	id ret = [prefs objectForKey:key];

	if(ret == nil) {
		ret = [defaultPrefs objectForKey:key];
	}

	return [ret boolValue];
}

static NSString* getValue(NSString *key) {
	return [prefs objectForKey:key] ?: [defaultPrefs objectForKey:key];
}

static void loadPrefs() {
	prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.noisyflake.magma.plist"];
}

static void initPrefs() {
	// Copy the default preferences file when the actual preference file doesn't exist
	NSString *path = @"/User/Library/Preferences/com.noisyflake.magma.plist";
	NSString *pathDefault = @"/Library/PreferenceBundles/MagmaPrefs.bundle/defaults.plist";
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if (![fileManager fileExistsAtPath:path]) {
		[fileManager copyItemAtPath:pathDefault toPath:path error:nil];
	}

	defaultPrefs = [[NSMutableDictionary alloc] initWithContentsOfFile:pathDefault];
}

%ctor {
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)loadPrefs, CFSTR("com.noisyflake.magma/prefsupdated"), NULL, CFNotificationSuspensionBehaviorCoalesce);
	initPrefs();
	loadPrefs();

	if (getBool(@"enabled")) {
		%init(_ungrouped);
	}
}

