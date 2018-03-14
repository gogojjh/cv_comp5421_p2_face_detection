close all
clc
im = imread('/home/jjiao/Documents/cv_ws/project_2/code/image/aerosmith-double.jpg');
scale = floor(36*1.5.^(0:1:log(min(size(im,1), size(im,2))/36)/log(1.5)));        
% scale = [72];
% d = 0;
% %     for j = 1:length(scale)
%     for j = 3:3
%         s = scale(j);
%         for y = 1:floor(size(im,1)/s)
%             for x = 1:floor(size(im,2)/s)
%                 im_split = im((y-1)*s+1:y*s, (x-1)*s+1:x*s, :);
%                 im_resize = im_split;
% %                 im_resize = imresize(im_split, [36, 36]);   
%                 d = d+1;
%                 subplot(floor(size(im,1)/s), floor(size(im,2)/s), d);
%                 imshow(im_resize);
%             end
%         end
%     end
size(im)
im_split = im(1:size(im,1), 1:size(im,2), :); % row, column
imshow(im_split);