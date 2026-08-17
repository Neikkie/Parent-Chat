# Setup Instructions for Media and Location Features

## Required Permissions

To use the media upload and location tagging features, you need to add the following permissions to your project:

### 1. Location Permissions

In Xcode:
1. Select the **Parent Chat** target
2. Go to the **Info** tab
3. Add the following keys under "Custom iOS Target Properties":

- **Privacy - Location When In Use Usage Description**
  - Value: `We need your location to tag where you post from`

### 2. Photo Library Permissions

The PhotosPicker handles permissions automatically, but you may want to add:

- **Privacy - Photo Library Usage Description** (Optional)
  - Value: `We need access to your photo library to share images in posts`

## Firebase Storage Setup

### 1. Enable Firebase Storage

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Click on **Storage** in the left sidebar
4. Click **Get Started**
5. Accept the default security rules for now (we'll update them)
6. Choose a Cloud Storage location
7. Click **Done**

### 2. Update Storage Security Rules

In Firebase Console, go to **Storage → Rules** and replace with:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /posts/{userId}/{allPaths=**} {
      allow read: if request.auth != null;
      allow create, update: if request.auth != null
        && request.auth.uid == userId
        && request.resource.size < 10 * 1024 * 1024
        && request.resource.contentType.matches('image/.*');
      allow delete: if request.auth != null
        && request.auth.uid == userId;
    }
  }
}
```

## Testing

After completing the setup:

1. **Test Image Upload**: Create a post with 1-5 images
2. **Test Video Upload**: Create a post with a video (the app will generate a thumbnail)
3. **Test Location**: Grant location access and tag your current location in a post
4. **Test Combined**: Create a post with text, images, and location

## Limitations

- Maximum 5 images per post
- 1 video per post (cannot mix with images in the same post)
- Videos are uploaded with auto-generated thumbnails
- Location requires user permission
