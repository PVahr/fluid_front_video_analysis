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
        connectivity = 200000;

        % first, plot all the steps separately IF Verbose
        obj.p.reader.CurrentTime = 0.;
        if obj.opt.Verbose
            f = readFrame(obj.p.reader);
            figure
            subplot(2, 1, 1); montage({f, rgb2gray(f)})
            subplot(2, 1, 2); montage({f(:, :, 1), f(:, :, 2), f(:, :, 3)}, 'Size', [1, 3])
            figure
            bw = flipud( imbinarize(rgb2gray(f),'global'));
            subplot(2, 1, 1); montage({bw, edge(bw, 'sobel')})
            subplot(2, 1, 2); histogram(rgb2gray(f))
        end

        i=1; obj.p.reader.CurrentTime = 0.;
        while hasFrame(obj.p.reader)
            %read the single frame
            f = readFrame(obj.p.reader);
            f = rgb2gray(f);
%            f = f(:, :, 1); % change here to use only one RGB channel
            f = flipud( imbinarize(f,'global'));
            % flip - the front in going UP -- follow this also in velcity_maps.m
            f = bwareaopen(f, 50);
            f = ~bwareaopen(~f, connectivity);
            f = edge(f, 'Sobel');
            
            if i == 1 %store them for later
	            first_frame = f;
            end
            last_frame = f;
            if mod(i,5000) == 0 
	            fprintf('Extracting front from frame %u of %u\n', i, round(vid.Duration*vid.FrameRate))
            end
            i=i+1;
        end
        figure
        imshow(first_frame)
        figure
        imshow(last_frame)
        end

        function crop_video_in_space(obj)
            % this function allows to crop the video in space coordinates
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
                close(vid_out);
                fprintf('Cropped video generated and saved correctly. Enjoy :)\n')
	        end
        end

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