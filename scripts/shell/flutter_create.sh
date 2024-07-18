android_namespace=$(echo $ANDROID_PACKAGE_NAME | cut -d'.' -f1,2)
android_project_name=$(echo $ANDROID_PACKAGE_NAME | cut -d'.' -f3)
cd starter
flutter create --org $android_namespace --project-name $android_project_name --platform=android .

ios_namespace=$(echo $IOS_PACKAGE_NAME | cut -d'.' -f1,2)
ios_project_name=$(echo $IOS_PACKAGE_NAME | cut -d'.' -f3)

flutter create --org $ios_namespace --project-name $ios_project_name --platform=ios .
cd ..
