This folder will have the "hard-linked" customized Telegraf configuration file. The hardlink refers to parent folder.

Why we have this?
The bind-mount is based on inode. Modifying a file in such a way that inode of the file changes, whill break the the bind-mount - i.e., you will not see those changes inside the container.
If you are using some editor like vim, when you save the file it does not save the file directly, rather it creates a new file and copies it into place. This breaks the bind-mount. Since saving the file effectively changes the inode, changes will not propagate into the container.

This is a known limitation of file-mounts and is not fixable.

To overcome this issue, we have following options:

1. Mount a directory instead of a file.
2. Use 'atomic\_save' options that are present in some editors.
3. use set backupcopy=yes - this is only for vi editor
4. Restart the container after the modification.
5. Create a hardlink - changes to file will retain the inode.

As optiond 1-4 are not feasible for telegraf, we chose the option-5. Hence, we have this custom folder.

