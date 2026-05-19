# Story: Capture a receipt image from camera or gallery
ID: STORY-003
Status: done
Feature: capture

## Intent
As a user who has finished entering people, I want to capture a receipt — either by taking a photo with the camera or by picking an existing image from my gallery — so that the captured image can be passed to extraction.

## Context
This story implements the entry point to receipt processing, sitting at the `/capture` route. It replaces the placeholder `CaptureScreen` that STORY-001 currently navigates to from the people screen. After this story is done, the end-to-end flow becomes: People (STORY-001) → Capture (this story) → Extract (STORY-002) → Assign (placeholder for now).

Per explicit user decisions (2026-05-19): full-screen with two visible CTAs (Take Photo, Pick from Gallery); after acquisition the screen shows a preview with "Use this photo" / "Retake or repick" before navigating to `/extract`; max-1600px resize is applied before storing; on permission denial an inline error + "Open Settings" button is shown near the offending CTA while the other CTA remains usable; on picker cancellation a transient toast "No image selected" is shown; no visual AC for this story.

Behavior on image decode/resize failure (corrupt file, unsupported format) is intentionally not specified in any AC — the implementer should choose a reasonable behavior. Flag in review if a specific behavior is required.

## Acceptance Criteria
- [x] AC-1 [behavioral]: Given the user lands on the `/capture` route, when the screen renders for the first time, then a "Take Photo" button and a "Pick from Gallery" button are both visible, no image preview is rendered, no permission-denied indicator is shown, and `billState.imageBytes` is unchanged from its prior value.

- [x] AC-2 [behavioral]: Given the initial 2-CTA state, when the user taps "Take Photo" and the OS reports camera permission as granted (either previously granted or freshly granted in response to a prompt), then the camera picker is presented to the user.

- [x] AC-3 [behavioral]: Given the initial 2-CTA state, when the user taps "Pick from Gallery" and the OS reports photo-library permission as granted, then the gallery picker is presented to the user.

- [x] AC-4 [behavioral]: Given a picker (camera or gallery) returns a selected image, when the screen finishes processing it, then (a) the image is resized so its longest edge is at most 1600 logical pixels (preserving aspect ratio; if the original is already ≤1600 on every edge, no resize is applied), (b) the resulting bytes are stored in `billState.imageBytes`, and (c) the screen transitions to the preview state.

- [x] AC-5 [behavioral]: Given the screen is in the preview state, when it renders, then the resized image is displayed as a preview AND a "Use this photo" button and a "Retake or repick" button are both visible. The two original CTAs ("Take Photo" / "Pick from Gallery") are NOT visible in this state.

- [x] AC-6 [behavioral]: Given the preview state and "Use this photo" is tapped, when navigation runs, then the app navigates to the `/extract` route. `billState.imageBytes` is not modified by the navigation itself.

- [x] AC-7 [behavioral]: Given the preview state and "Retake or repick" is tapped, when the tap is processed, then `billState.imageBytes` is set to `null` and the screen returns to the initial 2-CTA state.

- [x] AC-8 [behavioral]: Given a picker (camera or gallery) is open and the user cancels it without selecting an image, when control returns to the screen, then (a) a transient snackbar/toast "No image selected" is shown, (b) the screen remains in (or returns to) the initial 2-CTA state, and (c) `billState.imageBytes` is not modified.

- [x] AC-9 [behavioral]: Given the user taps "Take Photo" and the OS reports camera permission denied (either freshly denied or persistently denied from a prior session), when control returns to the screen, then (a) an inline error message appears near the "Take Photo" button indicating the camera permission is denied, (b) an "Open Settings" button visible alongside that error opens the OS settings app for this app when tapped, and (c) the "Pick from Gallery" button remains tappable and functional.

- [x] AC-10 [behavioral]: Given the user taps "Pick from Gallery" and the OS reports photo-library permission denied, when control returns to the screen, then (a) an inline error message appears near the "Pick from Gallery" button indicating the photo-library permission is denied, (b) an "Open Settings" button alongside that error opens the OS settings app, and (c) the "Take Photo" button remains tappable and functional.

## Non-goals
- Editing or cropping the image before storing (no in-app crop / rotate / filter UI).
- Multiple receipts per bill — `billState.imageBytes` holds at most one image; selecting a new one replaces the previous.
- Visual acceptance criteria — behavioral only for this story per user decision.

## Verification notes

2026-05-19 — verifier: PASS. All 10 behavioral AC satisfied. 10 widget tests in test/screens/capture_screen_test.dart (one per AC) plus 3 resizer unit tests in test/services/image_resizer_test.dart cover the resize math (3200x2000 → 1600x1000, 1000x2400 → ~666x1600, 1000x800 unchanged). Snackbar text exact match "No image selected" verified. Permission-denied flow correctly preserves the other CTA's functionality and Open Settings invokes acquirer.openAppSettings. AC-7 verified imageBytes cleared to null on retake. Full suite 42/42 passing; flutter analyze clean. No scope violations.
