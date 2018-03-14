clc
clear
train_path_nega = '../data/train_non_face_scenes/';
train_path_nega_split = '../data/train_non_face_scenes_split/';

image_files = dir( fullfile( train_path_nega, '*.jpg') ); %Caltech Faces stored as .jpg
num_images = length(image_files)
d = 0;
for i = 1:num_images
    filename = strcat(image_files(i).folder, '/', image_files(i).name);
    im = imread(filename);
    s = 36;
    for j = 1:20
        y = floor(rand()*(size(im,1)-36)+1);
        x = floor(rand()*(size(im,2)-36)+1);
        
        img_split = im(y:y+35, x:x+35, :);
        d = d + 1;
        imwrite(img_split, strcat(train_path_nega_split, int2str(d), '.jpg'));        
    end
end

%     for y = 1:floor(size(im,1)/s)
%         for x = 1:floor(size(im,2)/s)
%             img_split = im((y-1)*s+1:y*s, (x-1)*s+1:x*s, :);
%             d = d + 1;
%             imwrite(img_split, strcat(train_path_nega_split, int2str(d), '.jpg'));
%         end    
%     end