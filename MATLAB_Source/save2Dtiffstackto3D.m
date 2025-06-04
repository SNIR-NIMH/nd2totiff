function ret=save2Dtiffstackto3D(inputtifs,outputtif,compress,outputtype)

% ret=save2Dtiffstackto3D(inputtifs,outputtif,compress)
% 
% INPUTTIFS       Either a directory containing multiple tif files, or a
%                 regex style expression, e.g. /home/data/ABC_Z*.tif
% OUTPUTTIF       Output 3D tif file
% COMPRESS        yes/no flag, if the output tif image is compressed or not
% OUTPUTTYPE      (Optional) Either uint16 (default) or float32, if the input
%                 images are float32.

if nargin<4
    outputtype='uint16';
end
if ~strcmpi(outputtype,'uint16') && ~strcmpi(outputtype,'float32')
    fprintf('ERROR: Output type must be either uint16 or float32.\n');
    ret=0;
    return;
end

tic
if ~ischar(inputtifs)
    fprintf('Input tifs must be a directory or a regex style string. E.g. test/ABC_Z*.tif\n');
    ret=0;
    return
end
if isfile(outputtif)
    fprintf('WARNING: Output file exists. I will overwrite.\n');
end

if isfolder(inputtifs)
    A=rdir(fullfile(inputtifs,'*.tif'));
    if isempty(A)
        A=rdir(fullfile(inputtifs,'*.tiff'));
    end
    if isempty(A)
        fprintf('ERROR: Input folder does not contain .tif or .tiff files.\n');
        return;
    end
else
    A=rdir(inputtifs);
end
if nargin==2
    compress='no';
end
options.color     = false;
if strcmpi(compress,'no')
    options.compress  = 'no';
    fprintf('WARNING: Output will not be compressed.\n');
elseif strcmpi(compress,'yes')
    options.compress  = 'adobe';
    fprintf('WARNING: Output will be compressed.\n');
else
    fprintf('WARNING: Compress flag must be yes or no. You entered %s\n',compress);
    fprintf('WARNING: Output will not be compressed.\n');
    options.compress='no';
end
options.message   = true;
options.append    = false;
options.overwrite = true;



L=length(A);
% fprintf('%d tif files found\n',L);
x=imread(A(1).name);
dim=[size(x,1) size(x,2) L];
fprintf('Output image size %d x %d x %d\n',dim(1),dim(2),dim(3));

if strcmpi(outputtype,'uint16')
    vol=zeros([size(x,1) size(x,2) L],'uint16');
    m=round(2*prod(size(vol))/(1024^3));
else
    vol=zeros([size(x,1) size(x,2) L],'single');
    m=round(4*prod(size(vol))/(1024^3));
end
fprintf('Required memory = %d GB.\n',m);
if m>32
    fprintf('WARNING: For very large images, it is better to use save4dTiff.sh script.\n');
end
for i=progress(1:L)
%     fprintf('.');
    x=imread(A(i).name);
    if strcmpi(outputtype,'uint16')
        vol(:,:,i)=uint16(x);
    else
        vol(:,:,i)=single(x);
    end
end
fprintf('\n');
if 2*numel(vol)<4*(1024^3)
    options.big       = false;
else
    options.big       = true;
end
if strcmpi(outputtype,'float32')
    vol=single(vol);
end
fprintf('Writing %s\n',outputtif);
saveastiff(vol,outputtif,options);
ret=1;
toc
