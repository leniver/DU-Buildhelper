# Dual Universe Augmented Reality Tools for builders

## Overview  
This project provides augmented reality (AR) tools designed to assist builders in **Dual Universe**. With tools like the **Straight Line Drawing Tool**, you can create precise and symmetrical designs, making your building process more efficient and accurate.  

## Features  
- **Straight Line Drawing Tool:**  
  - Easily draw straight lines to help align and structure your builds.  
  - Ideal for creating clean, symmetrical, and professional designs.  


## Installation  
Follow these steps to set up the AR tools in your construct:  

- Add a **Programming Board** to the construct you are working on.
- Open the JSON file from this repository and copy its contents.
- Paste the copied JSON code into the **Programming Board**.
- *(Optional)* If you want to save points from the last session, link a **Database** to the **Programming Board**.  

## Usage  
To activate and control the tools, use the **Programming Board** and the following commands:  

### Point Commands  
- **`/add <x>(+|-)<x_precision> <y>(+|-)<y_precision> <z>(+|-)<z_precision>`**: Add a point with voxel precision tools coordinates.  
  - **Examples**:  
    - `/add 23+45 132-22 77+1`  
    - `/add 34 12+23 87`  
- **`/rem`**: Remove the last inserted point.  
- **`/move <x>(+|-)<x_precision> <y>(+|-)<y_precision> <z>(+|-)<z_precision>`**: Move the selected point to the new position.  
  - **Examples**:  
    - `/move 50+10 120-5 30+0`  
    - `/move 10 20+15 40-3`  
- **`/close`**: Close the shape (requires at least 3 points).  
- **`/propagate <distance>`**: Propagate the last vector for the specified distance.  
- **`/clear`**: Clear all points.  
- **`/points`**: Print all points.  

### Save Commands  
- **`/save <name>`**: Save the current point configuration in the database with the given name.  
- **`/restore <name>`**: Restore a point configuration from the database with the given name.  
- **`/remove <name>`**: Remove a point configuration from the database with the given name.  
- **`/displaysave`**: Display all saved point configurations.  

### Global Commands  
- **`/config`**: Print the current configuration.  
- **`/config <key> <value>`**: Set a specific configuration.  
- **`/help`**: Print this help message.  


## Roadmap  
Planned features include:  
- Additional drawing tools (curves, grids, etc.).  
- Enhanced AR visualization of in-game structures.  
- Integration with in-game Lua scripting for expanded functionality.  

## Contributions  
Contributions are welcome! Feel free to fork this repository, make improvements, and submit a pull request.  

## License  
This project is licensed under the [MIT License](LICENSE).  
