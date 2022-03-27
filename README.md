# Mr.Kaplan
![image](https://img.shields.io/badge/powershell-5391FE?style=for-the-badge&logo=powershell&logoColor=white) ![image](https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white)<br />

## Description
MrKaplan is a tool aimed to help red teamers to stay hidden and clear as much as traces possible. It works by saving information such as the time it ran, under which user and "reverting" the computer to look like before MrKaplan ran.<br />
This tool is inspired by <a href="https://github.com/mufeedvh/moonwalk">MoonWalk</a>, a similar tool for Unix machines.<br />
You can read more about it in the <a href="https://github.com/idov31/MrKaplan/wiki">wiki</a> page. (COMING SOON)<br /><br />

## Features
- Stopping event logging.
- Clearing files artifacts.
- Clearing registry artifacts.
- Can run for multiple users.

## Usage
- Before you start your operations on the computer, run MrKaplan with begin flag and whenever your finish run it again with end flag.

- **THIS PROGRAM MUST RUN AS AN ADMINISTRATOR (FOR NOW)**<br />

<img src="Pictures/usage.png" />

## TODO
- Add an option to run as user.
- Add exclusion support.
- Add time stomping support.
- Add more artifacts (WMI, inet cache, etc.).

## Acknowledgements
- https://github.com/PowerShellMafia/PowerSploit
- https://github.com/hlldz/Phant0m

## Disclaimer
I'm not responsible in any way for any kind of damage that is done to your computer / program as cause of this project. I'm happily accept contribution, make a pull request and I will review it!