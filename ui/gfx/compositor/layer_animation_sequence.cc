// Copyright (c) 2011 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "ui/gfx/compositor/layer_animation_sequence.h"

#include <algorithm>

#include "base/debug/trace_event.h"
#include "ui/gfx/compositor/layer_animation_delegate.h"
#include "ui/gfx/compositor/layer_animation_element.h"

namespace ui {

LayerAnimationSequence::LayerAnimationSequence()
    : is_cyclic_(false),
      last_element_(0) {
}

LayerAnimationSequence::LayerAnimationSequence(LayerAnimationElement* element)
    : is_cyclic_(false),
      last_element_(0) {
  AddElement(element);
}

LayerAnimationSequence::~LayerAnimationSequence() {
}

void LayerAnimationSequence::Progress(base::TimeDelta elapsed,
                                      LayerAnimationDelegate* delegate) {
  TRACE_EVENT0("LayerAnimationSequence", "Progress");
  if (elements_.size() == 0 || duration_ == base::TimeDelta())
    return;

  if (is_cyclic_) {
    // If delta = elapsed - last_start_ is huge, we can skip ahead by complete
    // loops to save time.
    base::TimeDelta delta = elapsed - last_start_;
    int64 k = delta.ToInternalValue() / duration_.ToInternalValue() - 1;
    if (k > 0) {
      last_start_ += base::TimeDelta::FromInternalValue(
          k * duration_.ToInternalValue());
    }
  }

  size_t current_index = last_element_ % elements_.size();
  while ((is_cyclic_ || last_element_ < elements_.size()) &&
         (last_start_ + elements_[current_index]->duration() < elapsed)) {
    // Let the element we're passing finish.
    elements_[current_index]->Progress(1.0, delegate);
    last_start_ += elements_[current_index]->duration();
    ++last_element_;
    current_index = last_element_ % elements_.size();
  }

  if (is_cyclic_ || last_element_ < elements_.size()) {
    double t = 1.0;
    if (elements_[current_index]->duration() > base::TimeDelta()) {
      t = (elapsed - last_start_).InMillisecondsF() /
          elements_[current_index]->duration().InMillisecondsF();
    }
    elements_[current_index]->Progress(t, delegate);
  }

  if (!is_cyclic_ && elapsed == duration_) {
    last_element_ = 0;
    last_start_ = base::TimeDelta::FromMilliseconds(0);
  }
}

void LayerAnimationSequence::Abort() {
  size_t current_index = last_element_ % elements_.size();
  while (current_index < elements_.size()) {
    elements_[current_index]->Abort();
    ++current_index;
  }
  last_element_ = 0;
  last_start_ = base::TimeDelta::FromMilliseconds(0);
}

void LayerAnimationSequence::AddElement(LayerAnimationElement* element) {
  // Update duration and properties.
  duration_ += element->duration();
  properties_.insert(element->properties().begin(),
                     element->properties().end());
  elements_.push_back(make_linked_ptr(element));
}

bool LayerAnimationSequence::HasCommonProperty(
    const LayerAnimationElement::AnimatableProperties& other) const {
  LayerAnimationElement::AnimatableProperties intersection;
  std::insert_iterator<LayerAnimationElement::AnimatableProperties> ii(
      intersection, intersection.begin());
  std::set_intersection(properties_.begin(), properties_.end(),
                        other.begin(), other.end(),
                        ii);
  return intersection.size() > 0;
}

}  // namespace ui
