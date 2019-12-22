function drawplat3d(nodez)
import rvctools.*
load('robotxobstacle.mat','lcx','lcy','lcz','lmx','lmy','lmz');
hold on
nodenum = size(nodez,1);
for j=1:nodenum
    if size(nodez,2)==12
        xc = [nodez(j,1:2),nodez(j,12),0,0,nodez(j,3)];
        xr = [nodez(j,1:2),0,0,0,nodez(j,3)]; a = nodez(j,4:7); th = nodez(j,8:11);
    else
        xc = [nodez(j,1:2),nodez(j,4),0,0,0];
        xr = [nodez(j,1:2),0,0,0,0]; a = nodez(j,3)*ones(1,4); th = zeros(1,4);
    end
    cub = RigidCuboid(1,xc,[lcx,lcy,lcz]);
    patch('Vertices',cub.verticesStates.position','Faces',cub.faces,'FaceColor','b','FaceAlpha',0.5);
    
    xm = xr2m(xr,a,th,[lcx,lcy,lcz],[lmx,lmy,lmz]);
    % build mobile platform cuboid
    for i=1:4
        plat(i) = RigidCuboid(1,xm(i,:),[lmx,lmy,lmz]);
        patch('Vertices',plat(i).verticesStates.position','Faces',plat(i).faces,'FaceColor','y','FaceAlpha',0.5);
    end
end
hold off
end