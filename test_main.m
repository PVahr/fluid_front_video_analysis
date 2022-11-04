% script to test the class VideoAnalysis.m and run small analysis of video

clear all;
close all;
%my_test_vid = VideoAnalysis('./vid/DSC_8533_c.avi', 'Verbose', 'True');
my_test_vid = VideoAnalysis('./vid/DSC_8533.avi', 'Verbose', 'True');
my_test_vid_2 = VideoAnalysis('./vid/Forced_Flow_011_mu50_5x.mp4', 'Verbose', 'True');
% my_test_vid_2.binarize_video()
my_test_vid.crop_video_in_space()
