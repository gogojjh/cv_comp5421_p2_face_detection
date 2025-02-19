% Sliding window face detection with linear SVM. 
% All code by James Hays, except for pieces of evaluation code from Pascal
% VOC toolkit. Images from CMU+MIT face database, CalTech Web Face
% Database, and SUN scene database.

% Code structure:
% proj4.m <--- You code parts of this
%  + get_positive_features.m  <--- You code this
%  + get_random_negative_features.m  <--- You code this
%   [classifier training]   <--- You code this
%  + report_accuracy.m
%  + run_detector.m  <--- You code this
%    + non_max_supr_bbox.m
%  + evaluate_all_detections.m
%    + VOCap.m
%  + visualize_detections_by_image.m
%  + visualize_detections_by_image_no_gt.m
%  + visualize_detections_by_confidence.m

% Other functions. You don't need to use any of these unless you're trying
% to modify or build a test set:

% Training and Testing data related functions:
% test_scenes/visualize_cmumit_database_landmarks.m
% test_scenes/visualize_cmumit_database_bboxes.m
% test_scenes/cmumit_database_points_to_bboxes.m %This function converts
% from the original MIT+CMU test set landmark points to Pascal VOC
% annotation format (bounding boxes).

% caltech_faces/caltech_database_points_to_crops.m %This function extracts
% training crops from the Caltech Web Face Database. The crops are
% intentionally large to contain most of the head, not just the face. The
% test_scene annotations are likewise scaled to contain most of the head.

% set up paths to VLFeat functions. 
% See http://www.vlfeat.org/matlab/matlab.html for VLFeat Matlab documentation
% This should work on 32 and 64 bit versions of Windows, MacOS, and Linux
close all
clear 
clc
run('/home/jjiao/Documents/MATLAB/vlfeat/toolbox/vl_setup')

[~,~,~] = mkdir('visualizations');

data_path = '../data/'; %change if you want to work with a network copy

train_path_pos = fullfile(data_path, 'caltech_faces/Caltech_CropFaces'); %Positive training examples. 36x36 head crops

non_face_scn_path = fullfile(data_path, 'train_non_face_scenes'); %We can mine random or hard negatives from here
% non_face_scn_path = fullfile(data_path, 'train_non_face_scenes_split'); %We can mine random or hard negatives from here

test_scn_path = fullfile(data_path,'test_scenes/test_jpg'); %CMU+MIT test scenes
% test_scn_path = fullfile(data_path,'extra_test_scenes'); %Bonus scenes
% test_scn_path = fullfile(data_path,'simple_test/test_jpg'); %Debug test scenes

label_path = fullfile(data_path,'test_scenes/ground_truth_bboxes.txt'); %the ground truth face locations in the test set

%The faces are 36x36 pixels, which works fine as a template size. You could
%add other fields to this struct if you want to modify HoG default
%parameters such as the number of orientations, but that does not help
%performance in our limited test.
feature_params = struct('template_size', 36, 'hog_cell_size', 3, 'variant', 'UoCTTI', ...
                        'confidence_threshold', 0.4);

% if you already have trained parameters
features_exist = 1;
coef_exist = 1;

%% Step 1. Load positive training crops and random negative examples
num_negative_examples = 10000; %Higher will work strictly better, but you should start with 10000 for debugging
if features_exist == 0
    disp('[INFO] calculate features_pos and features_neg from images');    
    features_pos = get_positive_features( train_path_pos, feature_params );
    features_neg = get_random_negative_features( non_face_scn_path, feature_params, num_negative_examples);
else
    disp('[INFO] load features_pos and features_neg from mat');
    load('param/features_pos.mat');
    load('param/features_neg.mat');
end

% train_X: DxN; train_Y: 1xN
train_X = [features_pos; features_neg]';
train_Y = [ones(1, size(features_pos,1)), -1*ones(1, size(features_neg,1))];
disp('[INFO] size of train dataset');
disp(size(train_X))

%% step 2. Train Classifier
% Use vl_svmtrain on your training features to get a linear classifier
% specified by 'w' and 'b'
% [w b] = vl_svmtrain(X, Y, lambda) 
% http://www.vlfeat.org/sandbox/matlab/vl_svmtrain.html
% 'lambda' is an important parameter, try many values. Small values seem to
% work best e.g. 0.0001, but you can try other values

if coef_exist == 0
    disp('[INFO] calculate svm_w_b from features');    
%     w = rand((feature_params.template_size / feature_params.hog_cell_size)^2 * 31,1); %placeholder, delete
%     b = rand(1); 
    lambda = 0.0001;
    [w, b, INFO] = vl_svmtrain(train_X, train_Y, lambda);    
    disp('[INFO] report for the training')
    disp(INFO)    
else
    disp('[INFO] load svm_w_b from mat');
    load('param/svm_w.mat');
    load('param/svm_b.mat');
%     load('param/b_ap0.927_cell3_zoom0.9_scale1_conf_n1.1.mat');
%     load('param/w_ap0.927_cell3_zoom0.9_scale1_conf_n1.1.mat');    
end

%% step 3. Examine learned classifier
% You don't need to modify anything in this section. The section first
% evaluates _training_ error, which isn't ultimately what we care about,
% but it is a good sanity check. Your training error should be very low.

% fprintf('Initial classifier performance on train data:\n')
% confidences = [features_pos; features_neg]*w + b;
% label_vector = [ones(size(features_pos,1),1); -1*ones(size(features_neg,1),1)];
% [tp_rate, fp_rate, tn_rate, fn_rate] =  report_accuracy( confidences, label_vector );
% 
% % Visualize how well separated the positive and negative examples are at
% % training time. Sometimes this can idenfity odd biases in your training
% % data, especially if you're trying hard negative mining. This
% % visualization won't be very meaningful with the placeholder starter code.
% 
% non_face_confs = confidences( label_vector < 0);
% face_confs     = confidences( label_vector > 0);
% figure(2); 
% plot(sort(face_confs), 'g'); hold on
% plot(sort(non_face_confs),'r'); 
% plot([0 size(non_face_confs,1)], [0 0], 'b');
% hold off;
% 
% % ???
% % Visualize the learned detector. This would be a good thing to include in
% % your writeup!
% n_hog_cells = sqrt(length(w) / 31); %specific to default HoG parameters
% imhog = vl_hog('render', single(reshape(w, [n_hog_cells n_hog_cells 31])), 'verbose') ;
% figure(3); imagesc(imhog) ; colormap gray; set(3, 'Color', [.988, .988, .988])
% 
% pause(0.1) %let's ui rendering catch up
% hog_template_image = frame2im(getframe(3));
% % getframe() is unreliable. Depending on the rendering settings, it will
% % grab foreground windows instead of the figure in question. It could also
% % return a partial image.
% imwrite(hog_template_image, 'visualizations/hog_template.png')
    
%% step 4. (optional) Mine hard negatives
% Mining hard negatives is extra credit. You can get very good performance 
% by using random negatives, so hard negative mining is somewhat
% unnecessary for face detection. If you implement hard negative mining,
% you probably want to modify 'run_detector', run the detector on the
% images in 'non_face_scn_path', and keep all of the features above some
% confidence level.

%% Step 5. Run detector on test set.
% YOU CODE 'run_detector'. Make sure the outputs are properly structured!
% They will be interpreted in Step 6 to evaluate and visualize your
% results. See run_detector.m for more details.
[bboxes, confidences, image_ids] = run_detector(test_scn_path, w, b, feature_params);

% disp('[INFO] confidence:')
% disp(confidences);
disp('[INFO] number of bboxes:')
disp(length(bboxes));

% run_detector will have (at least) two parameters which can heavily
% influence performance -- how much to rescale each step of your multiscale
% detector, and the threshold for a detection. If your recall rate is low
% and your detector still has high precision at its highest recall point,
% you can improve your average precision by reducing the threshold for a
% positive detection.

%% Step 6. Evaluate and Visualize detections
% These functions require ground truth annotations, and thus can only be
% run on the CMU+MIT face test set. Use visualize_detectoins_by_image_no_gt
% for testing on extra images (it is commented out below).

% Don't modify anything in 'evaluate_detections'!
[gt_ids, gt_bboxes, gt_isclaimed, tp, fp, duplicate_detections] = ...
    evaluate_detections(bboxes, confidences, image_ids, label_path);

visualize_detections_by_image(bboxes, confidences, image_ids, tp, fp, test_scn_path, label_path)
% visualize_detections_by_image_no_gt(bboxes, confidences, image_ids, test_scn_path)

% visualize_detections_by_confidence(bboxes, confidences, image_ids, test_scn_path, label_path);

% performance to aim for
% random (stater code) 0.001 AP
% single scale ~ 0.2 to 0.4 AP
% multiscale, 6 pixel step ~ 0.83 AP
% multiscale, 4 pixel step ~ 0.89 AP
% multiscale, 3 pixel step ~ 0.92 AP




