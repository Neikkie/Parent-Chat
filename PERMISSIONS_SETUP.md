# Required App Permissions Setup

## ⚠️ CRITICAL: Add Location Permission NOW

**The app will show location errors without this!**

Before you can use location features (map view, location tagging), you **MUST** add location permissions:

### Steps to Add Location Permission:

1. In Xcode, select the **Parent Chat** project in the navigator (top of file list)
2. Select the **Parent Chat** target (under TARGETS)
3. Click on the **Info** tab (top of main window)
4. Under **Custom iOS Target Properties**, click the **+** button
5. Add the following key:
   - **Key**: `Privacy - Location When In Use Usage Description`
   - **Type**: String
   - **Value**: `We need your location to find nearby activities and tag your posts`

**This is required for the map view to work!**

### Alternative Method (if Info tab doesn't show):

1. Right-click on the **Parent Chat** folder in Xcode
2. Select **New File...**
3. Choose **Property List** and name it `Info.plist`
4. Add the following to the plist:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>We need your location to find nearby activities and tag your posts</string>
</dict>
</plist>
```

## Photo Library Permission (Optional but Recommended)

While PhotosPicker handles permissions automatically, you can add a custom message:

- **Key**: `Privacy - Photo Library Usage Description`
- **Type**: String
- **Value**: `We need access to your photo library to share images in posts`

## Testing Permissions

After adding the permissions:

1. **Delete the app** from your simulator/device (to reset permissions)
2. **Rebuild and run** the app
3. When you tap the location button in a new post, you should see a permission prompt
4. When you tap the photo/video button, PhotosPicker will handle permissions

## Without These Permissions

If you don't add the location permission:
- ❌ The app will **crash** when trying to request location access
- ❌ You'll see **"kCLErrorDomain error 1"** in the console
- ❌ Map view won't show your location
- ❌ Location tagging won't work
- ❌ Distance calculations won't work

## Quick Fix for Location Error:

If you see "kCLErrorDomain error 1":
1. **Add the location permission key** (see steps above)
2. **Delete the app** from simulator/device
3. **Clean build folder**: Product → Clean Build Folder (Cmd+Shift+K)
4. **Rebuild and run** the app
5. **Grant location permission** when prompted

The photo library permission is handled automatically by PhotosPicker, but adding a custom message improves the user experience.
