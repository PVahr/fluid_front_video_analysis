% script to test the class VideoAnalysis.m and run small analysis of video

clear all;
close all;
% first video
my_test_vid = VideoAnalysis('./vid/DSC_8758.MOV', 'Verbose', false);
% my_test_vid.crop_video_in_space()
% my_test_vid.crop_video_in_time()
my_test_vid.binarize_video()
% my_test_vid.load_class_variables()

% second video
my_test_vid_2 = VideoAnalysis('./vid/DSC_8576_MOV_2.5_x_ct.avi', 'Verbose', false);
my_test_vid_2.binarize_video()
% my_test_vid_2.crop_video_in_time()
% my_test_vid_2.load_class_variables()

my_test_vid.plot_h_front()
my_test_vid_2.plot_h_front()

