function nikon_biopipeline_stitch(XMLfile,EDFdir,outputdir,uid)

% nikon_biopipeline_stitch(XMLfile,EDFdir,outputdir)
% 
% XMLFile       The OMEXML file generated from the ND2 file. For the time being,
%               run the convert_to_ometiff.sh script with NUMLEVEL=0 and last
%               argument as yes, then manually copy the tmpdir/OME/METADATA.xml file
%               Nikon_BioPipeline/codes/convert_to_ometiff.sh file.nd2 file.ome.tiff no 0 12 yes
%               The script will fail but the METADATA will remain the temporary
%               folder.
% EDFDIR        The EDF directory created by nikon_biopipeline_EDF.sh script
%               where all EDFs from all channels are located.
% OUTPUTDIR     Output directory where stitched images will be written with
%               CXX.tif format.
% UID           (Optional) A unique id for the image that will be appended
%               at the end of each channel. This is useful if there are many
%               ZStackLooop images. 

% if isdeployed
%     numchannels=str2num(numchannels);
% %     overlap=str2num(overlap);
% end
if ~isfolder(EDFdir)
    fprintf('ERROR: %s does not exist.\n',EDFdir);
    return;
end
if nargin<4
    uid=[];
end

x=what(EDFdir);
EDFdir=x.path; % Get the full path of the EDFdir because symlinks will be generated
try
    x=xml2struct(XMLfile);
catch e
    fprintf('WARNING: XML file can''t be read due to possible Unicode characters. Converting to UTF-8.\n');
    a=tempname;
    a=[a '.xml'];
    f=fopen(XMLfile,'r');
    b = fread(f,'*uint8')';
    fclose(f);
    str=native2unicode(b,'UTF-8');
    f=fopen(a,'w');
    fprintf(f,'%s\n',str);
    fclose(f);
    x=xml2struct(a);
    delete(a);
end


N=length(x.OME.Image);
fprintf('%d tiles detected.\n',N);
numchannels=str2num(x.OME.Image{1}.Pixels.Attributes.SizeC);

X=zeros(N,1);Y=zeros(N,1);
for i=1:N
    if numchannels>1
        X(i)=str2num(x.OME.Image{i}.Pixels.Plane{1}.Attributes.PositionX);
        Y(i)=str2num(x.OME.Image{i}.Pixels.Plane{1}.Attributes.PositionY);
    else
        X(i)=str2num(x.OME.Image{i}.Pixels.Plane.Attributes.PositionX);
        Y(i)=str2num(x.OME.Image{i}.Pixels.Plane.Attributes.PositionY);
    end
end
res=[str2num(x.OME.Image{1}.Pixels.Attributes.PhysicalSizeX) ...
    str2num(x.OME.Image{1}.Pixels.Attributes.PhysicalSizeY)];
dim=[str2num(x.OME.Image{1}.Pixels.Attributes.SizeX) ...
    str2num(x.OME.Image{1}.Pixels.Attributes.SizeY)];




X1=round((X-min(X))/(res(1)));
Y1=round((Y-min(Y))/(res(1)));

% Now compute the overlap manually
a=X1/dim(1); % movement in fraction of dimension
b=abs(a(2:end)-a(1:end-1)); % difference between movements of successive tiles is 1-ovl
b=b(b>0.5 & b<1);  % assume movement is always > 50% and <100%, i.e. overlap is always <50% and >0%
b=1-b;  % overlap is 1-movement
ovl=mean(b);
ovl1=round(100*ovl);


if numchannels>1
    unit=x.OME.Image{1}.Pixels.Plane{1}.Attributes.PositionXUnit;
else
    unit=x.OME.Image{1}.Pixels.Plane.Attributes.PositionXUnit;
end
fprintf('Estimated overlap factor = %.2f%%, actual %d%%\n',100*ovl,ovl1);
ovl=ovl1/100;
fprintf('Image resolution = %.2f x %.2f %s\n',res(1),res(2),unit);


L=round(dim(1)*(1-ovl)); % L is the movement in pixels

% Recompute the movements
% subtract 8 pixels = 8/dim(1)=0.0035 from every percent movement
Y11=fix_movements(Y1,dim(1));
X11=fix_movements(X1,dim(2));


X2=round(X11/L); % X is width/column
Y2=round(Y11/L); % Y is height/row
maxR=max(Y2);maxC=max(X2);
C=maxC-X2;R=maxR-Y2;  % 0 based indexing of rows and columns, don't use them later
numrow=max(R)+1;numcol=max(C)+1;
fprintf('Number of rows = %d\n',numrow);
fprintf('Number of columns = %d\n',numcol);



% Read the dimension from actual images instead of headers. It is possible that
% a different header can be used for stitching.
A=rdir(fullfile(EDFdir,'*.tif'));
if isempty(A)
    fprintf('ERROR: No tif images found in %s\n',EDFdir);
    fprintf('ERROR: If you have used nikon_biopipeline_noEDF script, use the ZStackLoop_XXX folder.\n');
    return;
end
f=imfinfo(A(1).name);
dim=[f.Height f.Width];
odim=round([numrow*dim(1)*(1-ovl)+dim(1)*ovl  numcol*dim(2)*(1-ovl)+dim(2)*ovl]);
fprintf('Approximate output image size = %d x %d\n',odim(1),odim(2));
memmax=round(2*2*prod(odim)/(1024^3));
% Now about 2x RAM is needed
fprintf('Approximate minimum required memory %d GB.\n',memmax); 
if memmax >= 50
    fprintf('WARNING: I will do memory efficient computation, approximate require memory will be %d GB.\n', round(memmax/2));
    memsafe=true;
else
    memsafe=false;
end
if ~isfolder(outputdir)
    mkdir(outputdir);
else
    A=rdir(outputdir);
    if ~isempty(A)
        fprintf('WARNING: Output directory exists and is not empty. I will overwrite.\n')
        fprintf('WARNING: It is recommended that an empty or non-existing directory is assigned as output.\n');
    end
end
% tmpdir=basename(tempname); % DONT USE BASENAME, IT IS LINUX ONLY
[~,tmpdir, ~]=fileparts(tempname);
dummy=zeros([dim(1) dim(2)],'uint16');
for ch=0:numchannels-1
    cdir=[tmpdir '_C' num2str(ch,'%02d')];
    cdir=fullfile(outputdir,cdir);
    if ~isfolder(cdir)
        mkdir(cdir);
    end
    
    s=['C' num2str(ch,'%02d') '*.tif'];
    A=rdir(fullfile(EDFdir,s));
    if isempty(A)
        fprintf('ERROR: EDF images must be labeled as C00_*.tif, C01_*tif etc\n');
        return;
    end
    
    for k=1:length(A)
        
        s=['Tile' num2str(R(k),'%03d') 'x' num2str(C(k),'%03d') '.tif'];
        s=fullfile(cdir,s);
        if ispc
            copyfile(A(k).name,s);
        else % ln -fs doesn't work on Windows
            cmd=['ln -fs ' A(k).name ' ' s];
            system(cmd);
        end
    end
    
    for r=0:numrow-1
        for c=0:numcol-1
            s=['Tile' num2str(r,'%03d') 'x' num2str(c,'%03d') '.tif'];
            s=fullfile(cdir,s);
            if ~isfile(s)
                imwrite(dummy,s,'Compression','none');
            end
        end
    end
end



if isempty(gcp('nocreate'))
    if ispc
        tempdirname=tempname;
    else
        username=getenv('USER');
        tempdirname=tempname(fullfile('/home',username,'.matlab','local_cluster_jobs','R2022a'));
    end
    mkdir(tempdirname);
    cluster=parallel.cluster.Local();
    cluster.NumWorkers=8; 
    % Use only 2 parallelizations because images can be very big
    cluster.JobStorageLocation=tempdirname;
    fprintf('Temp Job directory = %s\n',tempdirname);
    pl=parpool(cluster);
else
    pl=[];
end

options.color     = false;
options.compress  = 'no';
options.message   = true;
options.append    = false;
options.overwrite = false;
options.big=true;
opt.x=options;

tic
for ch=0:numchannels-1
    cdir=[tmpdir '_C' num2str(ch,'%02d')];
    cdir=fullfile(outputdir,cdir);
    try
        if isempty(uid)
            outputimg=[x.OME.Image{1}.Attributes.Name '_C' num2str(ch,'%02d') '.tif'];
        else
            outputimg=[x.OME.Image{1}.Attributes.Name '_C' num2str(ch,'%02d') '_' uid '.tif'];
        end
        outputimg=strrep(outputimg,' ','_');
        outputimg=strrep(outputimg,'(','_');
        outputimg=strrep(outputimg,')','_');
        outputimg=strrep(outputimg,'.nd2','');
        outputimg=strrep(outputimg,'__','_');
        outputimg=fullfile(outputdir,outputimg);
    catch e
        if isempty(uid)
            outputimg=['C' num2str(ch,'%02d') '.tif'];
        else
            outputimg=['C' num2str(ch,'%02d') '_' uid '.tif'];
        end
        outputimg=fullfile(outputdir,outputimg);
    end
    if isfile(outputimg)
        fprintf('ERROR: Output image (%s) exists. I will not overwrite.\n',outputimg);
        return;
    end
 

    A=rdir(fullfile(cdir,'*.tif'));
    if isempty(A)
        fprintf('ERROR: Input folder (%s) does not contain any tif images.\n',cdir);
%         return;
    end
    f=imfinfo(A(1).name);
    dim=[f(1).Height f(1).Width];
%     fprintf('Tile dimension = %d x %d \n',dim(1),dim(2));
    overlap=round(dim*ovl);
    MergeX=[];MergeY=[];
    MergeXcell=cell(numrow,1);
    fprintf('Merging columns.\n');
    parfor r=0:numrow-1
        fprintf('%d,',r+1);
        MergeX = [];
        for c=0:numcol-1
            s=['Tile' num2str(r,'%03d') 'x' num2str(c,'%03d') '.tif'];
            s=fullfile(cdir,s);
            slice=uint16(imread(s));
            
            MergeX = Blend2D(MergeX, slice,2, overlap(2));
        end
        MergeXcell{r+1}=MergeX;
        MergeX=0;
        if mod(r,10)==0 fprintf('\n'); end;
        
    end
    fprintf('\n')
    MergeX=[];
    
  
    fprintf('Computing overlaps.\n');
    W=size(MergeXcell{1},2);
    
    % A lot of memory efficient merging
    % A further memory optimization can be done when MergeXCell and MergeY are
    % kept at uint16 and only part of the array are used as single for smoothing
    ramp = single(linspace(0, 1, overlap(1))');
    ramp = repmat(ramp, [1, W]);
    
    MergeYcell=cell(numrow-1,1);
    for r=1:numrow-1
        temp_start=single(MergeXcell{r}(end-overlap(1)+1:end,:));
        temp_end = single(MergeXcell{r+1}(1:overlap(1),:));            
        % There is no need to keep them as single any more, because these are
        % only going as replacements
        MergeYcell{r} = uint16(temp_start.*(1- ramp) + temp_end.* ramp); 
    end
    
    % Remove the boundaries of the MergeXcell elements because the boundaries
    % are already computed in MergeYcell
    MergeXcell{1}=MergeXcell{1}(1:end-overlap(1),:);
    for r=2:numrow-1
        MergeXcell{r}=MergeXcell{r}(overlap(1)+1:end-overlap(1),:);
    end
    MergeXcell{numrow}=MergeXcell{numrow}(overlap(1)+1:end,:);
    
    % Compute the merging indices and replace the values only for those indices.
    Wx=zeros(numrow,1);
    for r=1:numrow
        Wx(r)=size(MergeXcell{r},1);
    end
    
    Wy=zeros(numrow-1,1);
    for r=1:numrow-1
        Wy(r)=size(MergeYcell{r},1);
    end
    odim(1)=sum(Wx)+sum(Wy);
    odim(2)=size(MergeXcell{1},2);
    
    % =====================================================================
    % If required memory is > 50GB, do memory efficient optimization by writing
    % MergeXcell into disk, and reading it one by one
    if memsafe
        
        tempdir1=tempname(outputdir);
        fprintf('Writing temporary merging data in %s\n',tempdir1);
        mkdir(tempdir1);
        for r=progress(1:numrow)
            s=fullfile(tempdir1,[num2str(r,'%04d') '.h5']);
            h5create(s,'/data',size(MergeXcell{r}),'Datatype','uint16');
            h5write(s,'/data',MergeXcell{r});            
        end
        MergeXcell=0;
    end
    
    % =====================================================================
    
    fprintf('Merging rows.\n');
    MergeY=zeros(odim,'uint16');
    
    
    if ~memsafe
        MergeY(1:Wx(1),:)=MergeXcell{1};
        MergeY(Wx(1)+1:Wx(1)+Wy(1),:)=MergeYcell{1};
        for r=progress(2:numrow-1)
            d1=sum(Wx(1:r-1))+sum(Wy(1:r-1));
            MergeY(d1+1:d1+Wx(r),:)=MergeXcell{r};
            MergeXcell{r}=0;
            MergeY(d1+Wx(r)+1:d1+Wx(r)+Wy(r),:)=MergeYcell{r};
            MergeYcell{r}=0;
        end
        d1=sum(Wx(1:(numrow-1)))+sum(Wy);
        MergeY(d1+1:d1+Wx(numrow),:)=MergeXcell{numrow};
    else
        
        s=fullfile(tempdir1,[num2str(1,'%04d') '.h5']);        
        MergeY(1:Wx(1),:)=h5read(s,'/data');
        
        MergeY(Wx(1)+1:Wx(1)+Wy(1),:)=MergeYcell{1};
        for r=progress(2:numrow-1)
            d1=sum(Wx(1:r-1))+sum(Wy(1:r-1));
            s=fullfile(tempdir1,[num2str(r,'%04d') '.h5']);  
            MergeY(d1+1:d1+Wx(r),:)=h5read(s,'/data');            
            MergeY(d1+Wx(r)+1:d1+Wx(r)+Wy(r),:)=MergeYcell{r};
            MergeYcell{r}=0;
        end
        d1=sum(Wx(1:(numrow-1)))+sum(Wy);
        s=fullfile(tempdir1,[num2str(numrow,'%04d') '.h5']);  
        MergeY(d1+1:d1+Wx(numrow),:)=h5read(s,'/data');     
        rmdir(tempdir1,'s');
    end
    
    
    % ===============================
    % This requires 3x memory of the image, one for MergeXcell, one for MergeY,
    % and one for the last step of MergeY when the right hand side memory is
    % allocated first.
%     
%     MergeY=MergeXcell{1}(1:end-overlap(1),:);
%     for r=progress(1:numrow-1)
%         MergeY=[MergeY; MergeYcell{r}; MergeXcell{r+1}(overlap(1)+1:end-overlap(1),:)];
%     end
%     MergeY=[MergeY; MergeXcell{numrow}(end-overlap(1)+1:end,:)];
        
    
%   ==================================
%   Using the Blend2D function is too memory intensive, because the whole
%   array is duplicated. This is fine for the MergeX, because each array is just
%   one row.
%     for r=progress(1:numrow)       
%         MergeY = Blend2D(MergeY, MergeXcell{r}, 1, overlap(1), 3);        
%     end

    MergeXcell=0;
    MergeYcell=0;
%     MergeY = uint16(MergeY);
    

    fprintf('Writing %s\n',outputimg);
    if 2*prod(odim)<4*(1024^3)    
        imwrite(MergeY,outputimg,'Compression','none');
    else
        % why did I do opt.x instead of options? writing options here was giving
        % error with parfor loop, who knows why!
        saveastiff(MergeY,outputimg,opt.x);
    end
    MergeY=[];
    rmdir(cdir,'s');
end
toc

if ~isempty(pl)
    delete(pl);
    rmdir(tempdirname,'s');
end


end



function dataC = Blend2D(dataA, dataB, dim, overlap)

if isempty(dataA)
    dataC = dataB;
elseif dim == 2
    ny = size(dataA,1);
    temp_start = single(dataA(:, end-overlap+1: end));
    temp_end = single(dataB(:, 1:overlap));
    
    % linear blend
    ramp_start = single(linspace(0, 1, overlap));
    ramp_start = repmat(ramp_start, [ny, 1]);
    temp = uint16(temp_start.*(1- ramp_start) + temp_end.* ramp_start);
%     dim1=size(dataA);dim2=size(dataB);
%     dataC=zeros([dim1(1) dim1(2)+dim2(2)-overlap],'uint16');
%     dataC(:,1:dim1(2)-overlap)=dataA(:,1:end-overlap);
%     dataC(:,dim1(2)-overlap+1:dim1(2))=temp;
%     dataC(:,dim1(2)+1:dim1(2)+dim2(2)-overlap)=dataB(:,overlap+1:end);
       
     dataC = [dataA(:, 1: end-overlap), temp, dataB(:, overlap+1:end)];
     
elseif dim == 1 % this part will not be used
    
    nx = size(dataA,2);
    temp_start = single(dataA(end-overlap+1:end,:));
    temp_end = single(dataB(1:overlap,:));
    
    % linear blend
    ramp_start = single(linspace(0, 1, overlap)');
    ramp_start = repmat(ramp_start, [1, nx]);
    temp = uint16(temp_start.*(1- ramp_start) + temp_end.* ramp_start);
    
       
     dataC = [dataA(1: end-overlap,:); temp; dataB(overlap+1:end,:)];
     
end
end



function X2=fix_movements(X1,dim)
% This function takes a movement vector X in pixels, the movements of stage across all
% tiles. Then it subtracts 8 pixels from successive tiles until a new row/col is
% encountered. A new row/col is found so that the dX is larger than 50% of the
% dim
dX=round(dim/10);
X2=X1;
for i=2:length(X1)
    dx=abs(X1(i)-X1(i-1));
    
    if dx<dX
        X2(i)=X2(i-1);
    end
end
U=unique(X2);
for i=1:length(U)
    indx=find(X2==U(i));
    X2(indx)=mean(X1(indx));
end

end