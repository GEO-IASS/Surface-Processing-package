function [grid, pointSpacing] = parse_zygo_format(fileName)
% pasrse through the zygo export format and create a 2D grid of the
% topographic data and also outputs the point spacing

delimeter = ' ';
FID       = fopen(fileName);

numX = dlmread(fileName,delimeter,[3 2 3 2]);
numY = dlmread(fileName,delimeter,[3 3 3 3]);
pointSpacing = dlmread(fileName,delimeter,[7 6 7 6]);

numPts = numX*numY;

Zdata = textscan(FID,'%*f %*f %f','Delimiter',' ','HeaderLines',14,'TreatAsEmpty','No Data');
z     = Zdata{1,1};
grid = reshape(z,numX,numY);

end