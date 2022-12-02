%% Class that handles a single video. By default, handles the video 
% metadata (path, VideoReader object, etc) and the further analysis done/to be done on it.

% usage 
% myvid = VideoAnalysis(video_name_and_path, options)
% video_name_and_path = relative path to the video + name of the
%                       video with extension, like ./vid/DSC_XXXX.xxx
%                       (May fail on Windows due to \ instead of / )
% options.Verbose       will give you a ton of plots; especially important
%                       when binarizing for the first time
% options.Reload        will reload the front h(x, t), the waiting time
%                       matrix W, the VideoReader object, the time and 
%                       space vectors t and x from the file in 
%                        ./fronts/DSC_XXX/DSC_XXX.mat 
%                       "DSC_xxx" with a Nikon camera, can be whatever
%                       string

classdef VideoAnalysis < handle 
    properties
        p   % p == parameters, stores all video metadata (size, framerate, etc),
            % the instance of the VideoReader class that further containts all the size, framerate, etc etc
        opt % stores options of the class
        h   % h(x, t) matrix, matrix of the front height; size(h, 1) = orizonthal length of the frame;
            % size(h, 2) = obj.p.reader.NumFrames, i.e. the number of frames of
            % the video
        x   % x coordinate of the front; at the moment is in number of pixel, can be converted to mm;
            % it will be =1:size(h, 1)
        t   % time vector as (1:obj.p.reader.NumFrames ) */ obj.p.reader.FrameRate
        W   % Waiting time = cumulative sum of all the binarize frames. Has the size of the frame itself.
        analysis % class to hold several analysis-related variables. Runtime only, it's not saved to the .mat files
    end

    methods
        function obj = VideoAnalysis( video_name_and_path, options)
            arguments
                video_name_and_path     string
                options.Verbose         logical=false % print tons of extra stuff for debugging
                options.Reload          logical=false % reload the class itself, if it already exists in folder VideoAnalysis_classes
            end
            % paths of video and output .mat files, .eps files
            fprintf('Init of video %s\t', video_name_and_path)
            obj.p.name_and_path = video_name_and_path; % save full path
            [obj.p.filepath, obj.p.name, obj.p.ext] = fileparts(video_name_and_path); % save video struct
            obj.p.path_analysis = './fronts/' + obj.p.name + '/';
            obj.p.name_analysis = obj.p.name + '.mat'; % file to save h(x,t) and all class information
            obj.p.full_path_analysis = obj.p.path_analysis + obj.p.name_analysis;
            obj.p.full_path_figures = obj.p.path_analysis + obj.p.name + '.pdf'; % path to store .eps figures
            if ~isfile(obj.p.name_and_path) % check existance
                fprintf('Given video does not exists!\nAhooo!\n')
            end
            obj.p.reader = VideoReader(obj.p.name_and_path);
            
            % options
            obj.opt.Verbose = options.Verbose;
            obj.opt.Reload = options.Reload;
 
            if obj.opt.Verbose % print all video Reader info
                obj.p.reader
            end
            if obj.opt.Reload % then just re-load the .mat without goind through a new binarization!
                obj.load_class_variables()
            end
            fprintf('...done\n')
        end

        function binarize_video(obj)
        %% this function binarize the video (imbinarize, bwareaopen, edge 
        % detection with Sobel), and saves it in vid/xxx_bin.avi
        % *** will fail if the video is NOT in RGB (if so, removed 'rgb2gray' everywhere)  ***
        obj.p.connectivity = 20000; % connectivity for bwareaopen is defined here

        % first, plot all the steps separately IF Verbose
        % fig1: original, grayscale, RGB separately
        % fig2: binarize with global, bwareaopen, Sobel
        % fig3: x, y of the front directly form Sobel
        % fig4: cleaned up x, y of the front
        obj.p.reader.CurrentTime = 0.; % ugly, I need f later to initialize h(x, t) correctly
        f = readFrame(obj.p.reader);
        if obj.opt.Verbose % we do the plotting
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
            obj.x = 1:size(obj.h, 1); % initialize the x vector
            obj.t = (1:obj.p.reader.NumFrames)./obj.p.reader.FrameRate; % define the time vector
            obj.W = zeros(size(rgb2gray(f)), 'uint32'); % Initialize the waiting time matrix
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
            while hasFrame(obj.p.reader) && i <= obj.p.reader.NumFrames 
                f = readFrame(obj.p.reader);
                % here I do the binarization + Sobel; less lines => much
                % faster
                bw = bwareaopen(( imbinarize(rgb2gray(f),'global')), obj.p.connectivity);
                bw = edge(~bwareaopen(~bw, obj.p.connectivity), 'Sobel');
                writeVideo(vid_out, double(bw));
%                 obj.W = obj.W + uint32(bw); % update the waiting time
%                 matrix, but this is WRONG AS I AM NOT TAKING AVGS
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
                            % I substract the size of the frame to make it
                            % go upward
                            obj.h(j, i) = size(f, 1) - mean(find(col==1)); % take the mean value of the front points
                            obj.W(round(size(f, 1) - obj.h(j, i)), j) = obj.W(size(f, 1) - round(obj.h(j, i)), j) + 1; % add "1" to the front point of W
 
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
        figure; sgtitle(strcat(frame_title, ' frame'));
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
        %% save p, h, etc in obj.p.full_path_analysis
        % always called at the end of binarize_video()
        % also called in the constructor when given opt.Reload = true
            if exist(obj.p.full_path_analysis, 'file') 
                fprintf('%s already exists, IT WILL BE OVERWRITTEN\n', obj.p.full_path_analysis)
            end
            % ugly but necessary cause Matlab requires local variables
            h = obj.h; 
            p = obj.p; 
            x = obj.x; t = obj.t;
            W = obj.W; 
            save(char(obj.p.full_path_analysis), 'h', 'p', 'x', 't', 'W')
            clearvars 'h' 'p' 'x' 't' 'W'   % less ugly
            fprintf('h(x, t), p, x, t, W WRITTEN to %s\n', obj.p.full_path_analysis)
        end
        
        function load_class_variables(obj)
        %% loads h, p, etc from the appropriate .mat file in the /front
        % folder.
        % the idea is that you don't have to binarize the video every time
        % you want to re-load the front h(x, t)
            if ~exist(obj.p.full_path_analysis, 'file') 
                fprintf('Loading from %s, but the file does not exists!! Fail!!\n', obj.p.full_path_analysis)
                return
            end
            load(char(obj.p.full_path_analysis), 'h', 'p', 'x', 't', 'W')
            obj.h = h; obj.p = p; obj.x = x; obj.t = t;
            obj.W = W;
            clearvars 'h' 'p' 'x' 't' 'W'
            fprintf('h(x, t), p, x, t, W LOADED from %s\n', obj.p.full_path_analysis)
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
        
        function speed_up_the_video(obj)
        %% this function speeds up the video of a given factor
        % very useful for presentation purposes
        % The new, faster video will have the exact same frame rate as the
        % original one, but with less frames. In this way you can make it
        % very fast, up to 10x or more faster, without going to extremely
        % high fps that would then not display correctly.
        % There is clearly an entropy loss in this process, so may not be
        % good for data analysis.
        % There will also be a "fake" timescale then, the real analysis 
        % must always be done on the original video. 
        fprintf('The original video has a FrameRate of %g fps, rounded to %g fps.\n', obj.p.reader.FrameRate, round(obj.p.reader.FrameRate) )
        new_fps = input('Insert the new Frame Rate you want. IT MUST BE AN INTEGER MULTIPLE OF THE ORIGINAL, ROUNDED FRAMERATE.\n');

        if mod(new_fps, round(obj.p.reader.FrameRate)) ~= 0 % check if wrong fps
            fprintf('Wrong input, framerates are not integer multiples.\n')
            return % ugly?
        end
        name_speedup_video = obj.p.name + '_speedup_' + string( round(new_fps/round(obj.p.reader.FrameRate)) ) + 'x'; % name of new video
        choice = input('Do you want to create a new video named ' + name_speedup_video  + ' ? (Y/n)\nIn: ','s');
        if choice == 'Y' || choice == 'y' % create the new, faster video
            if isfile(obj.p.filepath + '/' + name_speedup_video + '.avi')
                fprintf('*** The speed-up video already exists, IT WILL BE OVERWRITTEN RIP BUONANOTTE CIAO ***\n')
            end
            % write the new video
            vid_out = VideoWriter(obj.p.filepath + '/' + name_speedup_video, 'Motion JPEG AVI');
            vid_out.FrameRate = obj.p.reader.FrameRate; % very imp
            open(vid_out);
            i=0; obj.p.reader.CurrentTime = 0; % start at the new frame
            while hasFrame(obj.p.reader)
                f = readFrame(obj.p.reader);
                if mod(i, round(new_fps/round(obj.p.reader.FrameRate)) ) == 0 % then, I write the new frame
                    writeVideo(vid_out, f);
                end
                if mod(i, 300) == 0 
                    fprintf('Processed 300 more frames.\n')
                end
                i = i+1;
            end
            close(vid_out);
            fprintf('Faster video generated and saved correctly. Enjoy :)\n')
        end
        
        end
        
        function plot_h_front(obj)
        %% this function plot h(x, t):
        % <h(x, t)>_x: avg over space, vs time
        % <h(x, t>_t: avg over time, vs space
        % all the h(x, t) toghether
        % Waiting time W

        fprintf('Plotting the front, it will be SAVED too in %s\n', obj.p.full_path_figures)
        
%         figure
%         subplot(2, 2, 1); plot(obj.t, mean(double(obj.h), 1), '-r', 'MarkerSize', 1, 'LineWidth', 3); hold on;
%          xlabel('time (s)'); ylabel('<h(x, t)>_x (pixels)'); title('mean height vs TIME, avg in space')
%         subplot(2, 2, 2); plot(obj.x, mean(obj.h, 2), '-r', 'LineWidth', 3); xlabel('space (pixels)'); ylabel('<h(x, t)>_t (pixels)'); title('mean height vs SPACE, avg in time')
% %       
%         subplot(2, 2, 4); imagesc(obj.W); title('Waiting time matrix')
%         
        figure; sgtitle('Front averaged in SPACE')
        subplot(2, 2, 1); 
        plot(obj.t, mean(double(obj.h), 1), '-r', 'MarkerSize', 1, 'LineWidth', 3, 'DisplayName', '<h(x, t)>_x'); hold on; % std +- mean
        plot(obj.t, mean(double(obj.h), 1) + std(double(obj.h), 0, 1), '--k', 'LineWidth', 1, 'DisplayName', '+ 1 std')
        plot(obj.t, mean(double(obj.h), 1) - std(double(obj.h), 0, 1), '--k', 'LineWidth', 1, 'DisplayName', '- 1 std')
        ylabel('Height (pixels)'); xlabel('time (s)'); legend; title('mean +- std of the front VS time');
        
        subplot(2, 2, 3); plot(obj.t, std(double(obj.h), 0, 1), 'k-', 'LineWidth', 3, 'DisplayName', 'std'); hold on;% std 
        plot(obj.t, std(double(obj.h), 0, 1) - std(double(obj.h(:, 1))), '-', 'LineWidth', 3, 'DisplayName', 'std - std at t = 0'); % std 
        ylabel('Std (pixels)'); xlabel('time (s)'); title('Std of the front VS time - LINLIN'); legend;
        
        subplot(2, 2, 4); loglog(obj.t, std(double(obj.h), 0, 1), 'k-', 'LineWidth', 3, 'DisplayName', 'std'); hold on;
        loglog(obj.t, std(double(obj.h), 0, 1) - std(double(obj.h(:, 1))), '-', 'LineWidth', 3, 'DisplayName', 'std - std at t = 0'); % std 
        ylabel('Std (pixels)'); xlabel('time (s)'); title('Std of the front VS time - LOGLOG'); legend;
        
        figure; sgtitle('Front averaged in TIME')
        subplot(2, 2, 1);
        plot(obj.x, mean(obj.h, 2), '-r', 'LineWidth', 3, 'DisplayName', '<h(x, t)>_t'); hold on;
        plot(obj.x, mean(double(obj.h), 2) + std(double(obj.h), 0, 2), '--k', 'LineWidth', 1, 'DisplayName', '+ 1 std')
        plot(obj.x, mean(double(obj.h), 2) - std(double(obj.h), 0, 2), '--k', 'LineWidth', 1, 'DisplayName', '- 1 std')
        legend;  xlabel('space (pixels)'); ylabel('<h(x, t)>_t (pixels)'); title('mean height vs SPACE, avg in time')
        subplot(2, 2, 3); imagesc(obj.W); title('Waiting time matrix')
        subplot(2, 2, 2); plot(obj.x, obj.h, 'LineWidth', 0.5); xlabel('space (pixels)'); ylabel('h(x, t) (pixels)'); title('all h(x, t) in time vs SPACE')
        subplot(2, 2, 4); title('Selected fronts')
        for i=1:size(obj.h, 2)
            if mod(i, 40) == 0
                plot(obj.x, obj.h(:, i), '-k', 'LineWidth', 1); hold on;
            end
        end
        xlabel('space (pixels)'); ylabel('h(x, t) at selected t (pixels)');
        saveas(gcf, char(obj.p.full_path_figures), 'pdf')

        end
        
        function compute_and_plot_power_spectrum(obj)
        %% Compute the power spectral density S(q) of the front h(x, t) and 
        % of the same front but with periodic boundary conditions added to
        % it.
        % Then, plot the time-averaged S(q) in both cases, +- the standard
        % devition given by time-fluctuations.
        
        % Variables:
        % obj.analysis.Sq       same size as obj.h, but the pixel length is half,
        %                       contains the postive power spectra for every frame
        % obj.analysis.Sq_avg   size as obj.x/2, contains the time-average power spectra
        % obj.analysis.q        same size as x/2, contains the wavevector of
        %                       Sq and Sq_avg
        % obj.analysis.h_tilted same as obj.h, but with periodic boundary
        %                       conditions enforced (see its plotting)
        
        % initialize stuff correctly
        % (note: h is in uint, Sq are double, trasformation in between)
        N = size(obj.W, 2);                         % horizontal length of the frame
        fshift = (-N/2:N/2-1)/N;                    % zero-centered full frequency range
        obj.analysis.q = 2*pi*fshift( fshift>=0 );  % positive wave-vector range
        obj.analysis.Sq = zeros(size(obj.h), 'double');
        obj.analysis.Sq_avg = zeros(size(obj.x), 'double');
        
        if mod( size(obj.h, 1), 2) ~= 0
            % the x coordinate has an ODD number of pixel
            % this can happen if the video was cropped by hand, but makes a
            % huge mess because it must be even to define all the Fourier
            % stuff correctly
            fprintf('*** AHHHHHH THE NUMBER OF PIXEL IS ODD!!! *** \n*** It MUST be EVEN to define all the frequencies correctly, fix it! ***\n')
        end
        
        % in order: convert to double, compute fft along 1st axis,
        % apply fftshift along first axis
        % compute absolute value of each element and square it
        % renormalize by N
        obj.analysis.Sq = abs( fftshift( fft( double(obj.h), [], 1), 1) ).^2./N;
        
        obj.analysis.Sq_avg = mean( obj.analysis.Sq, 2); % make avg over number of frames; this is the TIME avg spectra
        
        % cut away the negative part of the spectra. Will fail for N odd
        obj.analysis.Sq_avg = obj.analysis.Sq_avg( N/2+1:end ); 
        obj.analysis.Sq = obj.analysis.Sq (N/2+1:end, :); 
        
        q_min = 2*pi/(N); % minimu wave vector u can resolve
        fprintf('Minimum wave vector (pixel^{-1}): %f\n', q_min);
        
        main_fig = figure; sgtitle('Power spectra analysis (not tilted likely scales like q^-2  because of the fft of a jump function)')
        subplot(2, 2, 1); 
        plot(obj.analysis.q, obj.analysis.Sq_avg, '-r', 'LineWidth', 3, 'DisplayName', '<S(q)>_t'); hold on
        plot(obj.analysis.q, obj.analysis.Sq_avg - std(obj.analysis.Sq, 0, 2), '-', 'Color', "#A2142F", 'LineWidth', 3); alpha 0.5;
        plot(obj.analysis.q, obj.analysis.Sq_avg, '-', 'Color', "#D95319",   'LineWidth', 3)
        legend; xlabel('Wave vector (pixel^-1)'); ylabel('S(q) (a.u.?)')
        title('Normal power spectra, linlin') % lin lin plot
        
        subplot(2, 2, 2); % log log plot
        loglog(obj.analysis.q, obj.analysis.Sq_avg + std(obj.analysis.Sq, 0, 2), '-', 'Color', "#A2142F", 'LineWidth', 3); hold on;
        loglog(obj.analysis.q, obj.analysis.Sq_avg - std(obj.analysis.Sq, 0, 2), '-', 'Color', "#A2142F", 'LineWidth', 3); alpha 0.5;
        loglog(obj.analysis.q, obj.analysis.Sq_avg, '-', 'Color', "#D95319",   'LineWidth', 3)
        legend('<S(q)>_t', '+ 1 std', '-1 std'); xlabel('Wave vector (pixel^{-1})'); ylabel('S(q) (a.u.?)')
        title('Normal power spectra, loglog')

        % here I force PERIODIC BOUNDARY CONDITIONS.
        % a jump in the left/right coordinate can heavily fake your spectra
        % giving a q^-2 power law scaling, which is the FFT of a step
        % function
        m = (double(obj.h(1, :)) - double(obj.h(end, :)) )./ size(obj.h, 1); % vector of angular coefficients
        obj.analysis.h_tilted = double(obj.h) + obj.x'*m;
        % en external product is going on, it's a very compact way of 
        % substracting a linear interpolation from one side of the front 
        % to the other, such that the two extrema match.
        
        figure; sgtitle('Check of titled VS original fronts to force periodc boundary conditions')
        plot(obj.x, obj.h(:, 1), '-r', 'LineWidth', 3, 'DisplayName', 'original'); % first front
        hold on; plot(obj.x, obj.analysis.h_tilted(:, 1), '--r', 'LineWidth', 3, 'DisplayName', 'with period boundary conditions')
        plot(obj.x, obj.h(:, round(size(obj.h, 2)*0.5)), '-g', 'LineWidth', 3, 'DisplayName', 'original'); % middle front
        hold on; plot(obj.x, obj.analysis.h_tilted(:, round(size(obj.h, 2)*0.5)), '--g', 'LineWidth', 3, 'DisplayName', 'with period boundary conditions')
        plot(obj.x, obj.h(:, end), '-b', 'LineWidth', 3, 'DisplayName', 'original'); % last front
        hold on; plot(obj.x, obj.analysis.h_tilted(:, end), '--b', 'LineWidth', 3, 'DisplayName', 'with period boundary conditions')
        legend; xlabel('x (pixel)'); ylabel('Front (pixel)')

        % now I re-compute the spectra on the tilted front
        obj.analysis.Sq_tilted = abs( fftshift( fft( obj.analysis.h_tilted, [], 1), 1) ).^2./N;        
        obj.analysis.Sq_avg_tilted = mean( obj.analysis.Sq_tilted, 2); % make avg over number of frames; this is the TIME avg spectra
        % cut away the negative part of the spectra. Will fail for N odd
        obj.analysis.Sq_avg_tilted = obj.analysis.Sq_avg_tilted( N/2+1:end ); 
        obj.analysis.Sq_tilted = obj.analysis.Sq_tilted (N/2+1:end, :); 
        % follows plot of tilted pw spectra
        figure(main_fig); subplot(2, 2, 3); 
        plot(obj.analysis.q, obj.analysis.Sq_avg_tilted, '-r', 'LineWidth', 3, 'DisplayName', '<S(q)>_t'); hold on
        plot(obj.analysis.q, obj.analysis.Sq_avg_tilted - std(obj.analysis.Sq_tilted, 0, 2), '-', 'Color', "#A2142F", 'LineWidth', 3); alpha 0.5;
        plot(obj.analysis.q, obj.analysis.Sq_avg_tilted, '-', 'Color', "#D95319",   'LineWidth', 3)
        legend; xlabel('Wave vector (pixel^-1)'); ylabel('S(q) (a.u.?)')
        title('TILTED power spectra, linlin') % lin lin plot
        subplot(2, 2, 4); % log log plot
        loglog(obj.analysis.q, obj.analysis.Sq_avg_tilted + std(obj.analysis.Sq_tilted, 0, 2), '-', 'Color', "#A2142F", 'LineWidth', 3); hold on;
        loglog(obj.analysis.q, obj.analysis.Sq_avg_tilted - std(obj.analysis.Sq_tilted, 0, 2), '-', 'Color', "#A2142F", 'LineWidth', 3); alpha 0.5;
        loglog(obj.analysis.q, obj.analysis.Sq_avg_tilted, '-', 'Color', "#D95319",   'LineWidth', 3)
        legend('<S(q)>_t', '+ 1 std', '-1 std'); xlabel('Wave vector (pixel^{-1})'); ylabel('S(q) (a.u.?)')
        title('TILTED power spectra, loglog')
        end
        
        function compute_plot_velocity_matrix(obj)
        %% this function computes the velocity matrix of the video, 
        % starting from the waiting time matrix W.
        % The result is a matrix of size(W) in which every pixel is a
        % double that contains the velocity of the front in that point, in
        % pixel/s
        % At the end is the inverse of W, multiplied by the FrameRate
            obj.analysis.V = zeros(size(obj.W), 'double'); % initialize the velocity matrix correctly

            % compute it quick and fast, altough hardly readable:
            % make the inverse of all and only points that are not zero,
            % then multiply by FrameRate.
            obj.analysis.V(obj.W~=0) = obj.p.reader.FrameRate./double(obj.W(obj.W~=0));

            figure(); sgtitle('Velocity matrix and waiting time matrix')
            subplot(2, 1, 1)
            imshow(obj.W, 'DisplayRange',[min(obj.W, [], 'all') max(obj.W, [], 'all')]);
            c = colorbar;
            c.Label.String = 'Accumulation of front points (number of pixels, integer)';
            xlabel('x coordinate (pixel)'); ylabel('y coordinate (pixel)'); title('Waiting time matrix')

            subplot(2, 1, 2)
            imshow(obj.analysis.V,'DisplayRange',[min(obj.analysis.V, [], 'all') max(obj.analysis.V, [], 'all')])
            colormap(copper)
            c = colorbar;
            c.Label.String = 'Front velocity (pixel/s)';
            xlabel('x coordinate (pixel)'); ylabel('y coordinate (pixel)'); title('Velocity matrix')
        end
        
        function get_pixel_density(obj)
        %% calibrate the space coordinates with an appropriate 
        % pixel -> m conversion factor
        % space coordinates in meters, we love SI!!
        end


    end
end