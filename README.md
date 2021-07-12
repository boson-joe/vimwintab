vimwintab
=========

**A plugin that adds "IDE-like" tabs to Vim, which allows you to have regular
tabs you are used to in every window you want to.**

To find out how to use the plugin see a brief [User Guide](https://github.com/boson-joe/vimwintab/wiki/Vimwintab-User-Guide#vimwintab-user-guide).

To learn more about the plugin please refer to the [Table of Contents](https://github.com/boson-joe/vimwintab#table-of-contents) section at the end of this file.

To see the license this plugin is distributed on go to [License](https://github.com/boson-joe/vimwintab/blob/master/license.txt)

Description
----------

In Vim, we don't really have tabs in its regular meaning. Vim tabs encompass windows, but don't show what files are opened in these windows. So, long story short, **vimwintab** plugin adds to Vim a functionality of regular tabs that you can find in many text editors. Hence the name - "Vim Windows Tabs".

![open_files](https://user-images.githubusercontent.com/85287376/125200646-a1965600-e274-11eb-9761-b8e4cdfe7aa6.gif)

Each tab represents a buffer associated with a window. Multiple windows may have the same buffer opened as a tab. At one point of time any window may have 
one current tab, with the represented buffer displayed in the window. Current tab may be switched to the left or right one, and if you try to go beyond any end of the tab bar it will wrap.

![quickfix_command](https://user-images.githubusercontent.com/85287376/125200645-a0fdbf80-e274-11eb-869d-5f5399cadaed.gif)

Navigation between tabs is not interconnected with the buffer list and is done via plugin's own commands. To know how to use the plugin see the [User Guide](https://github.com/boson-joe/vimwintab/wiki/Vimwintab-User-Guide#vimwintab-user-guide).

![navigate_tabs](https://user-images.githubusercontent.com/85287376/125200647-a22eec80-e274-11eb-9950-1cd6ac6a3941.gif)

Tabs are added to windows according to the mode the plugin operates in. There are several of those, each of them provides different detection patterns which the plugin will follow to determine if a buffer needs to be added to a tab bar.

![new_window](https://user-images.githubusercontent.com/85287376/125200644-9fcc9280-e274-11eb-8149-0f2d1451bfa6.gif)

In general, plugin is very customizable - you can determine, how it will operate, in which mode, how individual tabs will look like, etc. To know how see [Customization Guide](https://github.com/boson-joe/vimwintab/wiki/Vimwintab-customization-guide#vimwintab-customization-guide) page.

![delete_win_buf](https://user-images.githubusercontent.com/85287376/125200642-9e9b6580-e274-11eb-8fec-c40d4109f288.gif)

![toggle_bars](https://user-images.githubusercontent.com/85287376/125277459-1c657c80-e31a-11eb-8488-83fa3732bf81.gif)

![tabs_tabs](https://user-images.githubusercontent.com/85287376/125277461-1cfe1300-e31a-11eb-8213-144e8a5378c2.gif)


Installation
------------

To know how to install the plugin go to [Installation Guide](https://github.com/boson-joe/vimwintab/wiki/Vimwintab-installation-guide) page.

Development
-----------

If you are interested in contributing to the plugin's development or have any any suggestions please refer to the [Development](https://github.com/boson-joe/vimwintab/wiki/Vimwintab-development#vimwintab-development) and [Contacts](https://github.com/boson-joe/vimwintab/wiki/Vimwintab-contacts#vimwintab-contacts) sections.

Table of Contents
-----------------

[[User Guide]](https://github.com/boson-joe/vimwintab/wiki/Vimwintab-User-Guide#vimwintab-user-guide) [[Customisation Guide]](https://github.com/boson-joe/vimwintab/wiki/Vimwintab-customization-guide#vimwintab-customization-guide) [[Installation Guide]](https://github.com/boson-joe/vimwintab/wiki/Vimwintab-installation-guide) [[License]](https://github.com/boson-joe/vimwintab/blob/master/license.txt) [[Development]](https://github.com/boson-joe/vimwintab/wiki/Vimwintab-development#vimwintab-development) [[Contacts]](https://github.com/boson-joe/vimwintab/wiki/Vimwintab-contacts#vimwintab-contacts)

-----

[Go up](https://github.com/boson-joe/vimwintab#vimwintab)
