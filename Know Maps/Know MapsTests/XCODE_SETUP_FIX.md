# Fixing "Could not find test host" Error

## Problem
When running tests, you see this error:
```
Could not find test host for Know MapsTests: TEST_HOST evaluates to
"/Users/.../Know Maps.app/Know Maps"
```

The issue is that the "Know MapsTests" target is looking for "Know Maps.app" but the actual app is named "Know Maps Prod.app".

## Solution: Fix Test Target Configuration in Xcode

### Option 1: Update Test Host in Xcode (Recommended)

1. **Open Xcode**
   ```bash
   open "Know Maps.xcodeproj"
   ```

2. **Select the Project**
   - Click on "Know Maps" in the Project Navigator (top-level blue icon)

3. **Select Know MapsTests Target**
   - In the project editor, select "Know MapsTests" from the TARGETS list

4. **Go to Build Settings**
   - Click the "Build Settings" tab
   - Make sure "All" and "Combined" are selected (not "Basic" and "Levels")

5. **Search for TEST_HOST**
   - Type "TEST_HOST" in the search box

6. **Update TEST_HOST Value**
   - Double-click the value for TEST_HOST
   - Change from:
     ```
     $(BUILT_PRODUCTS_DIR)/Know Maps.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Know Maps
     ```
   - To:
     ```
     $(BUILT_PRODUCTS_DIR)/Know Maps Prod.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Know Maps Prod
     ```

7. **Update BUNDLE_LOADER** (if present)
   - Search for "BUNDLE_LOADER"
   - Update similarly to match "Know Maps Prod.app/Know Maps Prod"

8. **Clean Build Folder**
   - Go to Product menu → Hold Option key → "Clean Build Folder"

9. **Build and Test**
   ```bash
   xcodebuild test -project "Know Maps.xcodeproj" -scheme "Know Maps" \
     -destination 'platform=iOS Simulator,name=iPhone 17' \
     -only-testing:Know_MapsTests
   ```

### Option 2: Use Know Maps ProdTests Target

Alternatively, move the new test files to the existing "Know Maps ProdTests" target:

1. **In Xcode Project Navigator**
   - Select each new test file (AssistiveChatHostServiceTests.swift, etc.)
   - Open File Inspector (⌘⌥1)
   - Under "Target Membership", uncheck "Know MapsTests"
   - Check "Know Maps ProdTests"

2. **Run Tests with ProdTests Target**
   ```bash
   xcodebuild test -project "Know Maps.xcodeproj" -scheme "Know Maps" \
     -destination 'platform=iOS Simulator,name=iPhone 17' \
     -only-testing:Know_MapsTests
   ```

### Option 3: Command Line Quick Fix

You can try updating the project.pbxproj file directly (backup first!):

```bash
# Backup project file
cp "Know Maps.xcodeproj/project.pbxproj" "Know Maps.xcodeproj/project.pbxproj.backup"

# Find and replace TEST_HOST references (macOS)
sed -i '' 's|Know Maps\.app/\$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Know Maps|Know Maps Prod.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Know Maps Prod|g' "Know Maps.xcodeproj/project.pbxproj"

# Clean and rebuild
xcodebuild clean -project "Know Maps.xcodeproj" -scheme "Know Maps"
```

## Verification

After fixing, verify the tests run:

```bash
# Build first
xcodebuild build -project "Know Maps.xcodeproj" -scheme "Know Maps" \
  -destination 'platform=iOS Simulator,name=iPhone 17'

# Run tests
xcodebuild test -project "Know Maps.xcodeproj" -scheme "Know Maps" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:Know_MapsTests/NetworkIntegrationTests/testPlaceSearchWithMockedNetwork_returnsExpectedResults
```

If successful, you should see:
```
Test Suite 'NetworkIntegrationTests' passed
     ✓ testPlaceSearchWithMockedNetwork_returnsExpectedResults (0.XXX seconds)
```

## Alternative: Run Tests in Xcode UI

1. **Open Xcode**
   ```bash
   open "Know Maps.xcodeproj"
   ```

2. **Open Test Navigator** (⌘6)

3. **Find Your Tests**
   - Expand "Know MapsTests" or "Know Maps ProdTests"
   - Find the new test classes

4. **Run Individual Test**
   - Hover over a test and click the play button ▶
   - Or press ⌘U to run all tests

This will show detailed results and any failures in the Xcode UI.

## Troubleshooting

### If tests still don't run:

1. **Check Code Signing**
   - Go to target's "Signing & Capabilities"
   - Ensure "Automatically manage signing" is checked
   - Select a valid development team

2. **Check Deployment Target**
   - Make sure test target deployment target matches app target
   - Should be iOS 18.0 or compatible

3. **Clean Derived Data**
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/Know_Maps-*
   ```

4. **Check Simulator**
   - Make sure iPhone 17 simulator is available and booted:
   ```bash
   xcrun simctl list devices | grep "iPhone 17"
   ```

5. **Use Any Simulator**
   - If iPhone 17 isn't available, use any iOS Simulator:
   ```bash
   xcodebuild test -project "Know Maps.xcodeproj" -scheme "Know Maps" \
     -destination 'platform=iOS Simulator,name=Any iOS Simulator Device'
   ```

## Expected Results

Once configured correctly, you should have:
- ✅ 136 test methods across 6 test files
- ✅ All tests compile and are discoverable
- ✅ Tests can run individually or as a suite
- ✅ Mock infrastructure works correctly

## Need Help?

If you continue to have issues:
1. Check that "Know Maps Prod" is the actual app target name
2. Verify the app builds successfully first
3. Try running one simple test first to isolate the issue
4. Check Xcode console for detailed error messages
