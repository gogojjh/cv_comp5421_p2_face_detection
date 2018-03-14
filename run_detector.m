% Starter code prepared by James Hays for CS 143, Brown University
% This function returns detections on all of the images in a given path.
% You will want to use non-maximum suppression on your detections or your
% performance will be poor (the evaluation counts a duplicate detection as
% wrong). The non-maximum suppression is done on a per-image basis. The
% starter code includes a call to a provided non-max suppression function.
function [bboxes, confidences, image_ids] = ...
    run_detector(test_scn_path, w, b, feature_params)
% 'test_scn_path' is a string. This directory contains images which may or
%    may not have faces in them. This function should work for the MIT+CMU
%    test set but also for any other images (e.g. class photos)
% 'w' and 'b' are the linear classifier parameters
% 'feature_params' is a struct, with fields
%   feature_params.template_size (probably 36), the number of pixels
%      spanned by each train / test template and
%   feature_params.hog_cell_size (default 6), the number of pixels in each
%      HoG cell. template size should be evenly divisible by hog_cell_size.
%      Smaller HoG cell sizes tend to work better, but they make things
%      slower because the feature dimensionality increases and more
%      importantly the step size of the classifier decreases at test time.

% 'bboxes' is Nx4. N is the number of detections. bboxes(i,:) is
%   [x_min, y_min, x_max, y_max] for detection i. 
%   Remember 'y' is dimension 1 in Matlab!
% 'confidences' is Nx1. confidences(i) is the real valued confidence of
%   detection i.
% 'image_ids' is an Nx1 cell array. image_ids{i} is the image file name
%   for detection i. (not the full path, just 'albert.jpg')

% The placeholder version of this code will return random bounding boxes in
% each test image. It will even do non-maximum suppression on the random
% bounding boxes to give you an example of how to call the function.

% Your actual code should convert each test image to HoG feature space with
% a _single_ call to vl_hog for each scale. Then step over the HoG cells,
% taking groups of cells that are the same size as your learned template,
% and classifying them. If the classification is above some confidence,
% keep the detection and then pass all the detections for an image to
% non-maximum suppression. For your initial debugging, you can operate only
% at a single scale and you can skip calling non-maximum suppression.

test_scenes = dir( fullfile( test_scn_path, '*.jpg' ));
num_test_scenes = min(30, length(test_scenes));

%initialize these as empty and incrementally expand them.
bboxes = zeros(0,4);
confidences = zeros(0,1);
image_ids = cell(0,1);

method_mod = 0;

for i = 1:num_test_scenes
      
    fprintf('Detecting faces in %s\n', test_scenes(i).name)
    img = imread( fullfile( test_scn_path, test_scenes(i).name ));
    img = single(img)/255;
    if(size(img,3) > 1)
        img = rgb2gray(img);
    end

    cur_bboxes = zeros(0, 4);
    cur_confidences = zeros(0, 0);
    classification_class = [];
    
    if method_mod == 0
        disp('[INFO] detect with method_mod 0');
        scale = floor(feature_params.template_size*1.5.^(0:1:log(min(size(img,1), size(img,2))/feature_params.template_size)/log(1.5)));    
        for j = 1:length(scale)
            s = scale(j);
            disp(strcat('Current scale: ', int2str(s)));
            for y = 1:floor(size(img,1)/s)
                for x = 1:floor(size(img,2)/s)
                    img_crop = img((y-1)*s+1:y*s, (x-1)*s+1:x*s, :);
                    img_resize = imresize(img_crop, [feature_params.template_size, feature_params.template_size]);   
                    hog = vl_hog(single(img_resize), feature_params.hog_cell_size, 'variant', feature_params.variant);
                    hog_compress = hog(:)';
                    confidence = hog_compress*w + b;
                    if (sign(confidence) == 1)
                        cur_bboxes = [cur_bboxes; [(x-1)*s+1, (y-1)*s+1, x*s, y*s]];
                        cur_confidences = [cur_confidences; confidence];
                    end
                    classification_class = [classification_class, sign(confidence)];
                end
            end
        end
    elseif method_mod == 1
        disp('[INFO] detect with method_mod 0');
        scale = 1.0;
        zoom = 0.8;
        while min(size(img,1), size(img,2))*scale >= feature_params.template_size
            img_resize = single(imresize(img, size(img)*scale));
            disp('Current scale');
            disp(scale);        
            for y = 1:floor(size(img_resize,1)/feature_params.template_size)
                for x = 1:floor(size(img_resize,2)/feature_params.template_size)
                    crop_min_y = (y-1)*feature_params.template_size;
                    crop_min_x = (x-1)*feature_params.template_size;
                    img_crop = img_resize(crop_min_y+1:crop_min_y+feature_params.template_size, ...
                                            crop_min_x+1:crop_min_x+feature_params.template_size, :);
                    hog = vl_hog(img_crop, feature_params.hog_cell_size, 'variant', feature_params.variant);
                    hog_compress = hog(:)';
                    confidence = hog_compress*w + b;
                    if confidence > feature_params.confidence_threshold
                        cur_bboxes = [cur_bboxes; [(crop_min_x+1)/scale, (crop_min_y+1)/scale, ...
                                                    (crop_min_x+feature_params.template_size)/scale, ...
                                                    (crop_min_y+feature_params.template_size)/scale]];
                        cur_confidences = [cur_confidences; confidence];
                    end                
                end
            end
            scale = scale * zoom;
        end
    end
    
    cur_image_ids(1:length(cur_bboxes),1) = {test_scenes(i).name};    
    
    %non_max_supr_bbox can actually get somewhat slow with thousands of
    %initial detections. You could pre-filter the detections by confidence,
    %e.g. a detection with confidence -1.1 will probably never be
    %meaningful. You probably _don't_ want to threshold at 0.0, though. You
    %can get higher recall with a lower threshold. You don't need to modify
    %anything in non_max_supr_bbox, but you can.
    [is_maximum] = non_max_supr_bbox(cur_bboxes, cur_confidences, size(img));

    cur_confidences = cur_confidences(is_maximum,:);
    cur_bboxes      = cur_bboxes(     is_maximum,:);
    cur_image_ids   = cur_image_ids(  is_maximum,:);
 
    bboxes      = [bboxes;      cur_bboxes];
    confidences = [confidences; cur_confidences];
    image_ids   = [image_ids;   cur_image_ids];
end




