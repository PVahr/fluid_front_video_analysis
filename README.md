# fluid_front_video_analysis
Matlab code to binarize and further analyse fronts of liquids in 2D.
It's a cleaned up version of the code I developed during my bachelor's thesis at the Universita' degli Studi di Milano, under the supervision of professor A. Vailati and doctor M. Carpineti.

The aim of this piece of code is to 'binarize' a RGB video of a 2D front and extract the front h(x). 
The variable h(x) contains the height, in pixel, of the front of a single frame. This is then repeated for every single frame, leading to the matrix h(x, t), whose size 1 is the width fo the frame and whose size 2 is the number of frames of the video.
The code also get the 'waiting time amatrix', W, which is a cumulative sum of all the binarize frames of the video.

The code also allows to crop the video in space or in time 'interactively', quite an handy feature.

### Input
a video of a 2d front that evolves in time 
### Options:
* Verbose = true/false; if true, print and plot a lot of very usefull stuff to check if the binarization of the video is correct
* Reload = true/false; if true, reload the front matrix h(x, t) and other variables from the appropriate .mat file stored in ./fronts/DSC_xxx/DSC_xxx/.mat              

### Output:
* the binarized video that contains the front only, in ./vid/xxx_bin.xxx
* a vector h(x) with the front, that evolves in time and is stored like a 2d matrix h(x, t); the waiting time matrix W and their x and t vector; the parameters of the video (path, VideoReader object, etc) stored as a small class  named p. All these variables are saved in ./fronts/vid_name/vid_name.mat
* optional: a video cropped in space, in ./vid/xxx_c.xxx
* optional: a video cropped in time, in ./vid/xx_ct.xxx
* optional: plotting of the h(x, t), averaged in different ways, and W; The plots are also saved in a .pdf in ./vid/xxx/xxx.pdf

### Code structure:
* class VideoAnalysis.m: main class that does everything. Call the different methods of the class to binarize the video, cropt it interactively in space and/or time, save the binarize video and the front h(x,t) and do the power spectra analysis
* a test_main file to test the VideoAnalysis class, where you will find examples on how to use it
* in /vid/ folder there are 2 videos to be used as a test

### Notes:
* binarization is done with ''imbinarize'' using 'global' method; may not work for your case, if so tweak it till works.
* a violent "bwareaopen' function is applied, with a connectivity parameter of 20 000 or so. This works great to remove everything that is not the front itself, but may fail for your own specific video. If so, tweak it.
* edge detection is done with the ''edge'' function of Matlab, using the standard 'sobel' method. Works for my video, but it might fail in your case; if so, tweak it till it works.
* if tweaking the above 3 points does not make it work, maybe the problem is in the video: contrast and illumination must be already good to be able to analyse them
* may fail on Windows due to wrong paths (/ instad of \, tested on Linux only)
* there is currently no background substraction 

### Usage example
With Verbose = true, you can call binarize_video() and you will see all the different stages of the binarization steps, for the first, middle, last frames (here only the last one):
![Screenshot](docs_pics/bin_check.png) 

The binarization interface, when Verbose = true,  spits out when the front has more than one "1" pixel; if so, it will take the average:
![Screenshot](docs_pics/binarization_interface_w_verbose.png) 

The plotting of h(x, t) is basic but does the job:
![Screenshot](docs_pics/front_plot.png)

This is the handy interactive cropping of the video:
![Screenshot](docs_pics/interactive_cropping.png)

This is the hand cropping in time of the video, based on the frame number:
![Screenshot](docs_pics/interactive_time_cropping.png)


### TODO/bugs
* h(x, t) is FLIPPED upside down, but the fronts are not. Probably because the imshow starts by defauly in the top left corner instead that in the bottom eft; easy fix
* the compute_and_plot_power_spectrum() function is garbage at the moment
* the 'get_pixel_density()' is not implemented 






