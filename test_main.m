%% script to test the class VideoAnalysis.m and run small analysis of video
% set 'Verbose' to true the first times you use it!
% 'Reload' re-loads the front variables (h(x, t), W) from the appropriate
% .mat file. First you binarize, then you can reload all the times
% afterward.

clear all;
close all;


%% declare the videos
% first video
my_test_vid = VideoAnalysis('./vid/DSC_8758.MOV', 'Verbose', false, 'Reload', true);

% second video
my_test_vid_2 = VideoAnalysis('./vid/DSC_8576_MOV_2.5_x_ct.avi', 'Verbose', false, 'Reload', true);

%% binarize
% my_test_vid.binarize_video()
% my_test_vid_2.binarize_video()

% otherwise, you can explicitly call "my_test_vid.load_class_variables()"
% which is automatically called if you give 'Reload' true option in the
% constructor of the class.

%% crop in time
% my_test_vid.crop_video_in_time()
% my_test_vid_2.crop_video_in_time()

%% crop in space
% my_test_vid.crop_video_in_space()
% my_test_vid_2.crop_video_in_space()

%% speed up the video (for presentations)
% my_test_vid.speed_up_the_video()
% my_test_vid_2.speed_up_the_video()

%% plot the fronts
% my_test_vid.plot_h_front()
my_test_vid_2.plot_h_front()

%% velocity map matrix
% my_test_vid.compute_plot_velocity_matrix()
my_test_vid_2.compute_plot_velocity_matrix()

%% power spectra
my_test_vid.compute_and_plot_power_spectrum()
my_test_vid_2.compute_and_plot_power_spectrum()

