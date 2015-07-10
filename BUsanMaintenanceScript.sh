#Asa's handy dandy Xsan user and class management script based on AD groups and accounts.
#Created October 2014
#Revised October 22, 2014
#Revised January 2015 - user folder case change, empty user folder deletion
#Revised February 18, 2015 - Dropbox ACLs, fix class folder lookup error, fix day of year error
#Revised June 23, 2015 - Persistent users, skip class folder if no valid classes, expired user file age

echo ""

#Test for root user
CurrentUser=$(id -p | grep 'uid' | awk '{print $2}')
if [ "$CurrentUser" != "root" ]
	then
		echo "This script requires root access.  Log in as root before running."
		sudo su
		exit 0
fi

#Set Root Directory
RootDir="/Volumes/BUSAN"
echo "Mange folders in $RootDir? (Yes/No)"
read DefaultDir
if [ "$DefaultDir" = "Yes" ]
	then
		sleep 0
	else
		RootDir=""
fi

while [[ $RootDir = "" ]]; do
	echo "Specify path to root directory:"
	read RootDir
done

UserDir=$RootDir/Users
ClassesDir=$RootDir/Classes
TempDir=$RootDir/ScriptTempFiles
mkdir -p $UserDir
mkdir -p $ClassesDir
mkdir -p $TempDir

echo ""
echo "Loading Persistent Users"

cat /Volumes/BUSAN/Software/Scripts/ClassFolders/PersistentUsers.txt >> $TempDir/ClassLists.txt

echo ""

#Scan for classes
echo "Scanning class enrollment groups."
AllClasses=$(dseditgroup Xsan\ Classes | grep -A 200 GroupMembership | grep BUAD | awk '{ print $1}' | sed 's/BUAD\\//g' | grep -v Xsan)
echo "$AllClasses" | while read Class; do
	ClassList=$(dseditgroup "$Class" | grep -A 200 GroupMembership | grep BUAD | awk '{ print $1}' | sed 's/BUAD\\//g' | grep -v Xsan | grep -v MASSCOMM | grep -v Genovese | grep -v Mendoza | grep -v Manns | grep -v Cronan | grep -v Studio | grep -v Dough)
	
	#Check if class list is empty
	if [ "$ClassList" = "" ]
		then
			sleep 0
		else
			echo "$Class" >> $TempDir/ValidClasses.txt
			echo "$ClassList" >> $TempDir/ClassLists.txt
	fi
done
echo ""

#Remove empty user folders
echo "Deleting empty user folders."

#Get all empty user folders
EmptyUserFolders=$(find $UserDir -type d -empty -maxdepth 1)

#Load All Empty User Folders list into Do Loop
echo "$EmptyUserFolders" | while read Folder; do

rm -fR $Folder

done

echo ""
echo "     Empty user folders deleted."
echo ""

echo "Making user folders lower case."
echo ""

#Get all existing folders
UserFolders=$(ls -1 "$UserDir" | grep -v '_')

#Load All User Folders list into Do Loop
echo "$UserFolders" | while read Folder; do
FolderLower=$(echo $Folder | tr "[:upper:]" "[:lower:]")

if [ "$Folder" != "$FolderLower" ]
	then
		mv $UserDir/$Folder $UserDir/$FolderLower
fi

#Close folder do Loop
done

echo "     Folder case conversion complete."
echo ""

#Create new user folders
echo "Creating user folders"
#Load New Users list into Do Loop
cat $TempDir/ClassLists.txt | while read User; do

#Create User Folder
mkdir -p $UserDir/$User

#Close User Input do Loop
done

echo ""
echo "     New user folders created."
echo ""
echo "Validating User Folders."
echo ""

#Update existing folders list
UserFolders=$(ls -1 "$UserDir" | grep -v '_')

#Load All User Folders list into Do Loop
echo "$UserFolders" | while read User; do

#Get User ID
UserID=$(id $User)

#Check if UserID is blank
if [ "$UserID" = "" ]
	then
		FileDate=$(date -r$(find "$UserDir/$User" -print0 | xargs -0 stat -f "%m %N" | sort -rn | head -1 | awk '{print $1}'))
		echo ""		
		echo "     $User has expired!  Most recent file modified $FileDate."
		echo ""
		echo "          Delete folder $UserDir/$User? (YES/NO)"
		read DeleteUser </dev/tty
		if [ "$DeleteUser" = "YES" ]
			then
				echo "Deleting folder $UserDir/$User!"
				rm -fR $UserDir/$User
				echo "$User has been deleted."
			else
				echo "Expired user $User folder was not removed."
		fi
		echo ""
fi

#Close folder do Loop
done

echo "     User folder validation complete."
echo ""
echo "Fixing user folder permissions. This may take a while."

#Update existing folders list
UserFolders=$(ls -1 "$UserDir" | grep -v '_')

#Load All User Folders list into Do Loop
echo "$UserFolders" | while read User; do

#Change Ownership
chown -R $User $UserDir/$User

#Set Permissions
chmod -R 700 $UserDir/$User

#Close Folder do Loop
done

echo ""
echo "     User folder permission repair complete."
echo ""
echo "Determining current semester."

Yr=$(date +%y)
DayOfYear0=$(date +%j)
DayOfYear=${DayOfYear0#0}

if (($DayOfYear<=135))
	then
		SemName=Spring
		SemNum=2
elif ((232<=$DayOfYear))
	then
		SemName=Fall
		SemNum=6
	else
		SemName=Summer
		SemNum=4
fi

SemFolder="20$Yr-$SemNum $SemName"
echo ""

#Fix Classes Folder Permissions
echo "Fixing Classes folder permissions."
chown root $ClassesDir
chgrp Xsan\ Classes $ClassesDir
chmod 750 $ClassesDir
chmod -RN $ClassesDir

echo ""

#Get old Class folders
echo "Setting previous semester folder permissions."

OldClassFolders=$(ls -1 $ClassesDir | grep -v '_' | grep -v "$SemFolder")

#Load old Folders list into Do Loop to reset permissions
echo "$OldClassFolders" | while read Folder; do

chown root "$ClassesDir/$Folder"
chgrp -R Xsan\ Faculty "$ClassesDir/$Folder"
chmod -R 770 "$ClassesDir/$Folder"

#Close old folder do loop
done

echo ""
echo "     Previous semester folder permission reset complete."
echo ""

#Check for valid classes.
if [ -e "$TempDir/ValidClasses.txt" ]
	then


		#Create folder for current semester
		echo "     Creating Semester Folder: $SemFolder"
		mkdir -p "$ClassesDir/$SemFolder"
		chown root "$ClassesDir/$SemFolder"
		chgrp Xsan\ Classes "$ClassesDir/$SemFolder"
		chmod 750 "$ClassesDir/$SemFolder"


		echo ""
		echo "     Semester folder creation complete."
		echo ""


		echo "Creating class folders."

		cat "$TempDir/ValidClasses.txt" | while read Class; do

			Course=${Class%???}
			ClassSuffix=$(cat /Volumes/BUSAN/Software/Scripts/ClassFolders/MASSCOMM-Courses.txt | grep "$Course" | awk '{print $2}')
			ClassFolderName=$Class$ClassSuffix

			mkdir -p "$ClassesDir/$SemFolder/$ClassFolderName"
			chown -R root "$ClassesDir/$SemFolder/$ClassFolderName"
			chgrp -R $Class "$ClassesDir/$SemFolder/$ClassFolderName"
			chmod -R 750 "$ClassesDir/$SemFolder/$ClassFolderName"

			mkdir -p "$ClassesDir/$SemFolder/$ClassFolderName/Drop Box"
			chown root "$ClassesDir/$SemFolder/$ClassFolderName/Drop Box"
			chgrp $Class "$ClassesDir/$SemFolder/$ClassFolderName/Drop Box"
			chmod 700 "$ClassesDir/$SemFolder/$ClassFolderName/Drop Box"
			chmod +a "Xsan Faculty:allow list,add_file,search,delete,add_subdirectory,delete_child,readattr,writeattr,readextattr,writeextattr,readsecurity,file_inherit,directory_inherit" "$ClassesDir/$SemFolder/$ClassFolderName/Drop Box"
			chmod +a "$Class:allow add_file,search,add_subdirectory,delete_child,readattr,writeattr,readextattr,writeextattr,readsecurity" "$ClassesDir/$SemFolder/$ClassFolderName/Drop Box"

		#Close class folder do loop
		done

	else
		echo "No valid classes for current term."
fi

echo ""

echo "Cleaning up temp files."
rm -fR $TempDir

echo ""
echo "Script complete."
echo ""