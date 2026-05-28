from pbxproj import XcodeProject

project = XcodeProject.load('ios/Runner.xcodeproj/project.pbxproj')
project.add_file('Runner/GoogleService-Info.plist', force=False)
project.save()
print("Successfully patched project.pbxproj!")
