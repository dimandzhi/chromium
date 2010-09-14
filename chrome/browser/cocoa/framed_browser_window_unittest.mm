// Copyright (c) 2009 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <Cocoa/Cocoa.h>

#include "base/scoped_nsobject.h"
#include "chrome/app/chrome_dll_resource.h"
#import "chrome/browser/cocoa/browser_window_controller.h"
#import "chrome/browser/cocoa/browser_frame_view.h"
#import "chrome/browser/cocoa/cocoa_test_helper.h"
#import "chrome/browser/cocoa/framed_browser_window.h"
#include "testing/gtest/include/gtest/gtest.h"
#import "testing/gtest_mac.h"
#include "testing/platform_test.h"
#import "third_party/ocmock/OCMock/OCMock.h"

class FramedBrowserWindowTest : public CocoaTest {
 public:
  virtual void SetUp() {
    CocoaTest::SetUp();
    // Create a window.
    const NSUInteger mask = NSTitledWindowMask | NSClosableWindowMask |
        NSMiniaturizableWindowMask | NSResizableWindowMask;
    window_ = [[FramedBrowserWindow alloc]
               initWithContentRect:NSMakeRect(0, 0, 800, 600)
               styleMask:mask
               backing:NSBackingStoreBuffered
               defer:NO];
    if (DebugUtil::BeingDebugged()) {
      [window_ orderFront:nil];
    } else {
      [window_ orderBack:nil];
    }
  }

  virtual void TearDown() {
    [window_ close];
    CocoaTest::TearDown();
  }

  // Returns a canonical snapshot of the window.
  NSData* WindowContentsAsTIFF() {
    [window_ display];

    NSView* frameView = [window_ contentView];
    while ([frameView superview]) {
      frameView = [frameView superview];
    }
    const NSRect bounds = [frameView bounds];

    [frameView lockFocus];
    scoped_nsobject<NSBitmapImageRep> bitmap(
        [[NSBitmapImageRep alloc] initWithFocusedViewRect:bounds]);
    [frameView unlockFocus];

    return [bitmap TIFFRepresentation];
  }

  FramedBrowserWindow* window_;
};

// Baseline test that the window creates, displays, closes, and
// releases.
TEST_F(FramedBrowserWindowTest, ShowAndClose) {
  [window_ display];
}

// Test that undocumented title-hiding API we're using does the job.
TEST_F(FramedBrowserWindowTest, DoesHideTitle) {
  // The -display calls are not strictly necessary, but they do
  // make it easier to see what's happening when debugging (without
  // them the changes are never flushed to the screen).

  [window_ setTitle:@""];
  [window_ display];
  NSData* emptyTitleData = WindowContentsAsTIFF();

  [window_ setTitle:@"This is a title"];
  [window_ display];
  NSData* thisTitleData = WindowContentsAsTIFF();

  // The default window with a title should look different from the
  // window with an empty title.
  EXPECT_FALSE([emptyTitleData isEqualToData:thisTitleData]);

  [window_ setShouldHideTitle:YES];
  [window_ setTitle:@""];
  [window_ display];
  [window_ setTitle:@"This is a title"];
  [window_ display];
  NSData* hiddenTitleData = WindowContentsAsTIFF();

  // With our magic setting, the window with a title should look the
  // same as the window with an empty title.
  EXPECT_TRUE([window_ _isTitleHidden]);
  EXPECT_TRUE([emptyTitleData isEqualToData:hiddenTitleData]);
}

// Test to make sure that our window widgets are in the right place.
TEST_F(FramedBrowserWindowTest, WindowWidgetLocation) {
  // First without tabstrip.
  NSCell* closeBoxCell = [window_ accessibilityAttributeValue:
                          NSAccessibilityCloseButtonAttribute];
  NSView* closeBoxControl = [closeBoxCell controlView];
  EXPECT_TRUE(closeBoxControl);
  NSRect closeBoxFrame = [closeBoxControl frame];
  NSRect windowBounds = [window_ frame];
  windowBounds.origin = NSZeroPoint;
  EXPECT_EQ(NSMaxY(closeBoxFrame),
            NSMaxY(windowBounds) -
            kFramedWindowButtonsWithoutTabStripOffsetFromTop);
  EXPECT_EQ(NSMinX(closeBoxFrame), kFramedWindowButtonsOffsetFromLeft);

  NSCell* miniaturizeCell = [window_ accessibilityAttributeValue:
                             NSAccessibilityMinimizeButtonAttribute];
  NSView* miniaturizeControl = [miniaturizeCell controlView];
  EXPECT_TRUE(miniaturizeControl);
  NSRect miniaturizeFrame = [miniaturizeControl frame];
  EXPECT_EQ(NSMaxY(miniaturizeFrame),
            NSMaxY(windowBounds) -
            kFramedWindowButtonsWithoutTabStripOffsetFromTop);
  EXPECT_EQ(NSMinX(miniaturizeFrame),
            NSMaxX(closeBoxFrame) + kFramedWindowButtonsInterButtonSpacing);

  // Then with a tabstrip.
  id controller = [OCMockObject mockForClass:[BrowserWindowController class]];
  BOOL yes = YES;
  BOOL no = NO;
  [[[controller stub] andReturnValue:OCMOCK_VALUE(yes)]
   isKindOfClass:[BrowserWindowController class]];
  [[[controller expect] andReturnValue:OCMOCK_VALUE(yes)] hasTabStrip];
  [[[controller expect] andReturnValue:OCMOCK_VALUE(no)] hasTitleBar];
  [[[controller expect] andReturnValue:OCMOCK_VALUE(yes)] isNormalWindow];
  [window_ setWindowController:controller];

  closeBoxCell = [window_ accessibilityAttributeValue:
                  NSAccessibilityCloseButtonAttribute];
  closeBoxControl = [closeBoxCell controlView];
  EXPECT_TRUE(closeBoxControl);
  closeBoxFrame = [closeBoxControl frame];
  windowBounds = [window_ frame];
  windowBounds.origin = NSZeroPoint;
  EXPECT_EQ(NSMaxY(closeBoxFrame),
            NSMaxY(windowBounds) -
            kFramedWindowButtonsWithTabStripOffsetFromTop);
  EXPECT_EQ(NSMinX(closeBoxFrame), kFramedWindowButtonsOffsetFromLeft);

  miniaturizeCell = [window_ accessibilityAttributeValue:
                     NSAccessibilityMinimizeButtonAttribute];
  miniaturizeControl = [miniaturizeCell controlView];
  EXPECT_TRUE(miniaturizeControl);
  miniaturizeFrame = [miniaturizeControl frame];
  EXPECT_EQ(NSMaxY(miniaturizeFrame),
            NSMaxY(windowBounds) -
            kFramedWindowButtonsWithTabStripOffsetFromTop);
  EXPECT_EQ(NSMinX(miniaturizeFrame),
            NSMaxX(closeBoxFrame) + kFramedWindowButtonsInterButtonSpacing);
  [window_ setWindowController:nil];
}

// Test that we actually have a tracking area in place.
TEST_F(FramedBrowserWindowTest, WindowWidgetTrackingArea) {
  NSCell* closeBoxCell =
      [window_ accessibilityAttributeValue:NSAccessibilityCloseButtonAttribute];
  NSView* closeBoxControl = [closeBoxCell controlView];
  NSView* frameView = [[window_ contentView] superview];
  NSArray* trackingAreas = [frameView trackingAreas];
  NSPoint point = [closeBoxControl frame].origin;
  point.x += 1;
  point.y += 1;
  BOOL foundArea = NO;
  for (NSTrackingArea* area in trackingAreas) {
    NSRect rect = [area rect];
    foundArea = NSPointInRect(point, rect);
    if (foundArea) {
      EXPECT_NSEQ(frameView, [area owner]);
      break;
    }
  }
  EXPECT_TRUE(foundArea);
}

