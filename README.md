# fluid_front_video_analysis
matlab code to binarize and further analyse fronts of liquids in 2D.
It's a cleaned up version of the code I developed during my bachelor's thesis at the Universita' degli Studi di Milano, under the supervision of professor A. Vailati and doctor M. Carpineti.

Input: a video of a 2d front that evolves in time 

Output:
* the binarized video that contains the front only
* a vector h(x) with the front, that evolves in time and is stored like a 2d matrix h(x, t)
* further analysis, like power spectral density and correlations functions based on h(x, t)
* a so-called "waiting time matrix", that represent a count of how much time the front spends in every pixel

Code structure:
* class VideoAnalysis.m: main class that does everything. Call the different methods of the class to binarize the video, cropt it interactively in space and/or time, save the binarize video and the front h(x,t) and do the power spectra analysis
* a test_main file to test the VideoAnalysis class, where you will find examples on how to use it
* in /vid/ folder there are 2 videos to be used as a test

Notes:
* binarization is done with ''imbinarize'' using 'global' method; may not work for your case, if so tweak it till works.
* a violent "bwareaopen' function is applied, with a connectivity parameter of 50 000 or so. This works great to remove everything that is not the front itself, but may fail for your own specific video. If so, tweak it.
* edge detection is done with the ''edge'' function of Matlab, using the standard 'sobel' method. Works for my video, but it might fail in your case; if so, tweak it till it works.
* if tweaking the above 3 points does not make it work, maybe the problem is in the video: contrast and illumination must be alrady good to be able to analyse them
* may fail on Windows due to wrong paths (/ instad of \, tested on Linux only)
* there is currently no background substraction 


# add pics example of front raw, binarize, h(x) here
# add pics of h(x, t) and of a waiting time matrix
