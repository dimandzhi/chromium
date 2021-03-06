// Copyright (c) 2011 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "chrome/browser/chromeos/login/screen_locker.h"
#include "chrome/browser/chromeos/login/screen_locker_delegate.h"

namespace chromeos {

ScreenLockerDelegate::ScreenLockerDelegate(ScreenLocker* screen_locker)
    : screen_locker_(screen_locker) {
}

ScreenLockerDelegate::~ScreenLockerDelegate() {
}

void ScreenLockerDelegate::ScreenLockReady() {
  screen_locker_->ScreenLockReady();
}

}  // namespace chromeos
