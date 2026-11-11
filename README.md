# digipad_flutter

A new Flutter project.

## Getting Started

# DigiTower 3D

A Flutter-based recreation of the DigiPad application with modern cross-platform support.

## Features

- **Cross-Platform**: Runs on iOS and Android
- **Landscape Orientation**: Optimized for landscape mode
- **Native Splash Screen**: Fast-loading native splash screens
- **Modern UI**: Built with Flutter's Material Design 3
- **Camera Integration**: Camera functionality for capturing images
- **Location Services**: GPS and location-based features
- **Permissions Management**: Proper permission handling for all platforms

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Xcode (for iOS development)
- Android Studio (for Android development)

### Installation

1. Clone the repository:

```bash
git clone https://github.com/josephchipock/digipad.git
cd digipad
```

2. Install dependencies:

```bash
flutter pub get
```

3. Run the app:

```bash
flutter run
```

## Project Structure

- `lib/` - Main application code
  - `main.dart` - Application entry point
  - `home_screen.dart` - Main home screen
  - `splash_screen.dart` - Custom splash screen (legacy)
- `assets/` - Application assets
  - `images/` - Image resources including app icon and splash
- `android/` - Android-specific configuration
- `ios/` - iOS-specific configuration

## Configuration

### App Icons

App icons are automatically generated using `flutter_launcher_icons` package.

### Splash Screens

Native splash screens are generated using `flutter_native_splash` package.

## Dependencies

Key dependencies include:

- `camera` - Camera functionality
- `geolocator` - Location services
- `permission_handler` - Permission management
- `flutter_launcher_icons` - App icon generation
- `flutter_native_splash` - Native splash screen generation

## License

This project is licensed under the MIT License.
