% script to test the class VideoAnalysis.m and run small analysis of video

clear all;
close all;
%my_test_vid = VideoAnalysis('./vid/DSC_8758.MOV', 'Verbose', 'True');
my_test_vid = VideoAnalysis('./vid/DSC_8758.MOV', 'Verbose', 'True');
my_test_vid_2 = VideoAnalysis('./vid/DSC_8576_MOV_2.5_x.avi', 'Verbose', 'True');
% my_test_vid_2.binarize_video()
my_test_vid.crop_video_in_space()
