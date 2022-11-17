%% Class that handles a single video. By default, handles the video 
% metadata and the further analysis done/to be done on it.
% the idea is to check automatically if the vidoe analysis already exist,
% to easily invoke it at later stages.

% usage 
% myvid = VideoAnalysis(video_name_and_path, options)
% video_name_and_path = relative path to the video + name of the
%                       video with extension, like ./vid/DSC_XXXX.avi
%                       (May fail on Windows due to \ instead of / )
% options.SaveFrontVideo    will save the front video for visual inspection in
%                          ./vid folder, named like DSC_XXXX_front.avi

classdef VideoAnalysis < handle 
    properties
        p % p == parameters, stores all video metadata (size, framerate, etc),
            % the instance of the VideoReader class that further containts all the size, framerate, etc etc
        opt % stores options of the class
        h % h(x, t) matrix, matrix of the front height; size(h, 1) = orizonthal length of the frame;
        % size(h, 2) = obj.p.reader.NumFrames, i.e. the number of frames of
        % the video
    end

    methods
        function obj = VideoAnalysis( video_name_and_path, options)
            arguments
                video_name_and_path     string
                options.SaveFrontVideo  logical=true % by default, will save the front video for visual inspection
                options.Verbose         logical=false % print tons of extra stuff for debugging
                options.Reload          logical=true % reload the class itself, if it alraady exists in folder VideoAnalysis_classes
            end
            fprintf('Init of video %s\t', video_name_and_path)
            obj.p.name_and_path = video_name_and_path; % save full path
            [obj.p.filepath, obj.p.name, obj.p.ext] = fileparts(video_name_and_path); % save video struct
            obj.p.path_analysis = './fronts/' + obj.p.name + '/';
            obj.p.name_analysis = obj.p.name + '.mat'; % file to save h(x,t) and all class information
            obj.p.full_path_analysis = obj.p.path_analysis + obj.p.name_analysis;
            obj.opt.SaveFrontVideo = options.SaveFrontVideo;
            obj.opt.Verbose = options.Verbose;
            if ~isfile(obj.p.name_and_path) % check existance
                fprintf('Given video does not exists!\nAhooo!\n')
            end
            obj.p.reader = VideoReader(obj.p.name_and_path);
            if obj.opt.Verbose % print all video Reader info
                obj.p.reader
            end
            fprintf('...done\n')
        end

        function binarize_video(obj)
        %% this function binarize the video (imbinarize, bwareaopen, edge 
        % detection with Sobel), and saves it in vid/xxx_bin.avi
        % WILL FAIL FOR VIDEOS IN GRAYSCALE ALREADY
        obj.p.connectivity = 20000; % connectivity for bwareaopen is defined here

        % first, plot all the steps separately IF Verbose
        % fig1: original, grayscale, RGB separately
        % fig2: binarize with global, bwareaopen, Sobel
        % fig3: x, y of the front directly form Sobel
        % fig4: cleaned up x, y of the front
        obj.p.reader.CurrentTime = 0.; % ugly, I need f later to initialize h(x, t) correctly
        f = readFrame(obj.p.reader);
        if obj.opt.Verbose
            % first frame binarization check
            obj.p.reader.CurrentTime = 0.;
            f = readFrame(obj.p.reader);
            plot_test_binarization_and_front_extraction(obj, f, 'first')
            
            % last frame binarization check
            obj.p.reader.CurrentTime = obj.p.reader.Duration - 1/obj.p.reader.FrameRate; % set to the very last frame
            f = readFrame(obj.p.reader);
            plot_test_binarization_and_front_extraction(obj, f, 'last')

            % middle frame binarization check
            obj.p.reader.CurrentTime = obj.p.reader.Duration*0.5; % set time in the middle
            f = readFrame(obj.p.reader);
            plot_test_binarization_and_front_extraction(obj, f, 'middle')
        end
        
        % now, ask if you want to proceed with binarization
        name_bin_video = obj.p.name + '_bin';
        choice = input('Do you want to create a new binarized video in ./vid/' + name_bin_video  + ' ? (Y/n)\nIn: ','s');
        choice_front_extr = input('Do you also want to extract the front matrix h(x, t)? (Y/n)\n', 's');
        
        if choice_front_extr == 'Y' || choice_front_extr == 'y' % initialize h(x, t) and appropriate folder
            obj.h = zeros([size(f, 2), obj.p.reader.NumFrames], 'uint64');
            fprintf('h matrix is %i * %i wide (oriz. pixel length * NumFrames)\n', size(obj.h, 1), size(obj.h, 2))
            if ~exist(obj.p.path_analysis, 'dir') % make a folder to store h(x, t) etc etc
                mkdir(obj.p.path_analysis)
                fprintf('Folder %s not found, made a new one.\n', obj.p.path_analysis)
            end
        end
        
        if choice == 'Y' || choice == 'y' % create the new, cropped video
            if isfile(obj.p.filepath + '/' + name_bin_video + '.avi')
                fprintf('*** The binarized video already exists, IT WILL BE OVERWRITTEN RIP BUONANOTTE CIAO ***\n')
            end
            vid_out = VideoWriter(obj.p.filepath + '/' + name_bin_video, 'Motion JPEG AVI');
            vid_out.FrameRate = obj.p.reader.FrameRate; % very imp
            open(vid_out);
            i=1; obj.p.reader.CurrentTime = 0;
            fprintf('Start of binarization...'); tstart = tic;
            while hasFrame(obj.p.reader) && i <= round(obj.p.reader.FrameRate*(obj.p.reader.Duration-1./obj.p.reader.FrameRate))
                f = readFrame(obj.p.reader);
                % here I do the binarization + Sobel; less lines => much
                % faster
                bw = bwareaopen(( imbinarize(rgb2gray(f),'global')), obj.p.connectivity);
                bw = edge(~bwareaopen(~bw, obj.p.connectivity), 'Sobel');
                writeVideo(vid_out, double(bw));
                
                % i = frame munber; j = column index;
                if choice_front_extr == 'Y' || choice_front_extr == 'y' % get h(x, t) 
                    for j=1:size(bw, 2) % cycle over x of front
                        col = bw(:, j); % get the single vertical columns
                        if ~any(col)
                            fprintf('*** Column %i of frame %i without any point!! ***!!!\n', j, i)
                            obj.h(j, i) = obj.h(j-1, 1);
                            fprintf('*** Replaced with neighbour value of %i, finger crossed, will fail for the first column***\n', obj.h(j-1, 1))
                        else
                            if sum(col)>1
                                fprintf('In column %i of frame %i there are %i points\n', j, i, sum(col))
                            end
                            obj.h(j, i) = mean(find(col==1)); % take the mean value of the front points
 
                        end
                    end
                end
                i = i+1;
            end
            close(vid_out); tend = toc(tstart); 
            fprintf('... finished successfully in %3.1f s.\nEnjoy :)\n', tend)
            choice = input('Do you want to save h(x,t) and all the class information (p, options) in ' + obj.p.path_analysis + obj.p.name_analysis + ' (Y/n)\nIn: ','s');
            if choice == 'Y' || choice == 'y'
                obj.save_class_variables()
            end
            end
        end


        function plot_test_binarization_and_front_extraction(obj, f, frame_title)
        % function that plots the frame, then grayscale, RGB, then
        % the binarize frame, then bin + bwareopen, then front
        % extraction
        figure; sgtitle(strcat(frame_title, 'frame'));
        subplot(2, 1, 1); montage({f, rgb2gray(f)}) % original, grayscale
        title('original, grayscale')
        subplot(2, 1, 2); montage({f(:, :, 1), f(:, :, 2), f(:, :, 3)}, 'Size', [1, 3]) % R, G, B channels separately
        title(' R, G, B channels separately')
        figure; sgtitle(strcat(frame_title, ' frame, binarization check'))
        bw = flipud( imbinarize(rgb2gray(f),'global'));
        bw_cleaned = bwareaopen(bw, obj.p.connectivity);
        bw_cleaned = ~bwareaopen(~bw_cleaned, obj.p.connectivity); % double cleaning of positive and negative island of pixel
        subplot(2, 1, 1); montage({bw, bw_cleaned}); title('binarize, binarize + bwareaopen')
        subplot(2, 1, 2); montage({edge(bw_cleaned, 'Sobel')}); title('Sobel edge detection')
        
        % follows the extraction of h(x)
        front = edge(bw_cleaned, 'Sobel');
        h = zeros([size(front, 2), 1]); % vector of the height
        x = 1:length(h); % pixel coordinate (quite useless)
        for i=1:size(front, 2) % cycle over x of front
            col = front(:, i);
            if ~any(col)
                fprintf('There is a column without any point!!\CASE NOT IMPLEMENTED!!!\n')
            end
            if sum(col)>1
                fprintf('In column %i there are %i points\n', i, sum(col))
                h(i) = mean(find(col==1)); % take the mean value of the front points
            else
                h(i) = find(col==1); % return the pixel position
            end
        end
        figure; sgtitle(strcat(frame_title, ' frame front extraction; x = pixel coordinate, h = front coordinate'))
        scatter(x, h); hold on; plot(x, h);   
        xlabel('pixel, x'); ylabel('fornt position (pixel, h(x))')
        end
    
        function save_class_variables(obj)
        % save p, h in obj.p.full_path_analysis
            if exist(obj.p.full_path_analysis, 'file') 
                fprintf('%s already exists, IT WILL BE OVERWRITTEN\n', obj.p.full_path_analysis)
            end
            % ugly but necessary cause Matlab requires local variables
            h = obj.h; 
            p = obj.p; 
            save(char(obj.p.full_path_analysis), 'h', 'p')
            clearvars 'h' 'p'
        end
        
        function crop_video_in_space(obj)
            %% this function allows to crop the video in space coordinates
            % INTERACTIVELY!!
            % will make a new video called original_video_c.avi , where _c =
            % 'cropped', in folder ./vid/
            satisfied = false;
            while ~satisfied
	            obj.p.reader.CurrentTime = 0; % pick 3 frames to be displayed
	            beg_frame = readFrame(obj.p.reader);
                obj.p.reader.CurrentTime=obj.p.reader.Duration*.5;
	            middle_frame = readFrame(obj.p.reader);
                obj.p.reader.CurrentTime=obj.p.reader.Duration-0.1;
	            end_frame = readFrame(obj.p.reader);
            
                rect = [0 0 size(beg_frame,2) size(beg_frame,1)];
	            fprintf('Select the first rectangle to crop all the frames in the same way\n')
	            figure(1);
	            [~, rect] = imcrop(middle_frame); % interactivness is here
	            close(1);
	            fprintf('You have choosen for the first frame the rectangle: \n')
	            disp(rect);
	            fprintf('But, since pixels are integer, it will be rounded to the pixel matrix:\n')
	            rect = round(rect); disp(rect)
	            figure; 
                subplot(1, 2, 1); montage({beg_frame, middle_frame, end_frame}, "BorderSize", 10, 'BackgroundColor', 'red')
                subplot(1, 2, 2); montage({imcrop(beg_frame, rect), imcrop(middle_frame, rect), imcrop(end_frame, rect)}, "BorderSize", 10, 'BackgroundColor', 'red')
            
	            choice = input('Are you satisfied? (Y/n)\nIn: ','s');
	            if choice == 'Y' || choice == 'y'
		            satisfied = true;
		            close all;
                end
                close all;
            end
            name_c_video = obj.p.name + '_c'; % add "_c" for the cropped video's name
            choice = input('Do you want to create a new, cropped, video named ' + name_c_video  + ' ? (Y/n)\nIn: ','s');
            if choice == 'Y' || choice == 'y' % create the new, cropped video
                if isfile(obj.p.filepath + '/' + name_c_video + obj.p.ext)
                    fprintf('*** The cropped video already exists, IT WILL BE OVERWRITTEN RIP BUONANOTTE CIAO ***\n')
                end
%                movie = read(obj.p.reader); % get the entire movie at once CAN FAIL FOR BIG FILES
                % Is like a 4-d tensor with the entire movie in it!
                % size(movie) %mov is in 4D matrix: [Height (Y), Width (X), RGB (color), frame] 
 %               movie_cropped=movie(rect(2):rect(4), rect(1):rect(3), :, :); % crop in a single, wonderfully parallelized shot! <3
                
                % write the new video
                vid_out = VideoWriter(obj.p.filepath + '/' + name_c_video, 'Motion JPEG AVI');
                vid_out.FrameRate = obj.p.reader.FrameRate; % very imp
                open(vid_out);
                i=0; obj.p.reader.CurrentTime = 0;
                while hasFrame(obj.p.reader) && i <= round(obj.p.reader.FrameRate*(obj.p.reader.Duration-1./obj.p.reader.FrameRate))
	                f = readFrame(obj.p.reader);
	                f = imcrop(f,rect);
                    writeVideo(vid_out, f);
                   	i = i+1;
                end
                close(vid_out); load gong.mat; sound(y);
                fprintf('Cropped video generated and saved correctly. Enjoy :)\n')
	        end
        end

        
        function crop_video_in_time(obj)
        %% this functions allows to interactively crop a video in time
        % and save the cropped video in _ct.avi file
        video_first_frame = 0;
        video_last_frame = obj.p.reader.NumFrames;
        satisfied = false;
        beg_frame = readFrame(obj.p.reader);
        obj.p.reader.CurrentTime=obj.p.reader.Duration * 0.5;
        middle_frame = readFrame(obj.p.reader);
        obj.p.reader.CurrentTime = (obj.p.reader.NumFrames-1)/obj.p.reader.FrameRate;
        end_frame = readFrame(obj.p.reader);
        figure; 
        montage({beg_frame, middle_frame, end_frame}, "BorderSize", 10, 'BackgroundColor', 'red'); title('First, middle, last original frames')
        while ~satisfied

            fprintf('Current frame interval: [%g, %g]\n',video_first_frame, video_last_frame);
            new_first_frame_number = input('Enter the number of the NEW first frame\n');
            new_last_frame_number = input('Enter the number of the NEW last frame\n');
            
            obj.p.reader.CurrentTime = new_first_frame_number / obj.p.reader.FrameRate; % pick 3 frames to be displayed
            new_beg_frame = readFrame(obj.p.reader);
            obj.p.reader.CurrentTime = new_last_frame_number / obj.p.reader.FrameRate * 0.5;
            new_middle_frame = readFrame(obj.p.reader);
            obj.p.reader.CurrentTime = (new_last_frame_number-1) / obj.p.reader.FrameRate;
            new_end_frame = readFrame(obj.p.reader);

            figure
            montage({beg_frame, middle_frame, end_frame, new_beg_frame, new_middle_frame, new_end_frame}, "BorderSize", 10, 'BackgroundColor', 'red', "Size",[2 3]);
            title('First, middle, last original --> NEW frames')
            choice=input('Are you satisfied? (Y/n)\nIn: ','s');
            if choice == 'Y' || choice == 'y'
                satisfied=true;
            end
        end
        name_ct_video = obj.p.name + '_ct'; % add "_ct" for the cropped video's name in time
        choice = input('Do you want to create a new, time-cropped, video named ' + name_ct_video  + ' ? (Y/n)\nIn: ','s');
        if choice == 'Y' || choice == 'y' % create the new, cropped video
            if isfile(obj.p.filepath + '/' + name_ct_video + '.avi')
                fprintf('*** The cropped video already exists, IT WILL BE OVERWRITTEN RIP BUONANOTTE CIAO ***\n')
            end
            % write the new video
            vid_out = VideoWriter(obj.p.filepath + '/' + name_ct_video, 'Motion JPEG AVI');
            vid_out.FrameRate = obj.p.reader.FrameRate; % very imp
            open(vid_out);
            i=0; obj.p.reader.CurrentTime = new_first_frame_number/obj.p.reader.FrameRate; % start at the new frame
            while hasFrame(obj.p.reader) && i <=  (new_last_frame_number - new_first_frame_number)
                f = readFrame(obj.p.reader);
                writeVideo(vid_out, f);
                i = i+1;
            end
            close(vid_out);
            fprintf('Time-cropped video generated and saved correctly. Enjoy :)\n')
        end

        
        close all;
        end
        %         
        function get_pixel_density(obj)
        %% calibrate the space coordinates with an appropriate 
        % pixel -> m conversion factor
        % space coordinates in meters, we love SI!!
        end

        function save_VideoAnalysis_class(obj)
        %% save this own class in a .mat file in the VideoAnalysis_classes
        % folder
        end

        function load_VideoAnalysis_class(obj)
        %% load this own class, looking at the appropriate .mat file in the
        % VideoAnalysis_classes folder
        % s.t. you do not have to re-do the whole analysis
        end
    
    end
end