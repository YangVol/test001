function [t,r,u1,u0,u_r,Pf_r,P_r,dphi_r,m_r,Dphi_t,Pl_t,tensial_t,M_s_t,zeta]=Transient_graduate_solver_all2(t_range,dt,dr,alpha,phi_o,r_ratio,KsMr,KfMr,KlMr,MmMr,delta_m,tau)

% This code solves for the transient evolution following a gradual
% injection. In the input:
% tau is the injection period (normalized)
% r_ratio=R_o^3/r_o^3; 
% KsMr is the ratio between solid bulk modulus K_s and regidity \Mu_r
% KfMr is the ratio between pore fluid bulk modulus K_f and regidity \Mu_r
% KlMr is the ratio between core fluid bulk modulus K_l and regidity \Mu_r
% MmMr is the ratio between mush regidity \mu_m and regidity \Mu_
% delta=dM/Mo is the ratio between injected magma and original core magma

%In the output: 
%t is time (normalized); r is rasial position (normalized by Ro)
%u1 is the displacement at r=R_o; u0 is displacement at r=r_o
%Pf_r is the final pore pressure as function of r
%P_r is total pressure as function of r
%dphi_r is change in porosity as function or r
%m_r is change in fluid content as function or r
%Pl_r is core pressure as function of time 
%M_s_t is the amount of magma 'leaked' into the shell as function or time
%tensile_t is the tensile stress at the mush-rock bounday, as function of
%time.

% All results are normalized by their respective scales
% This code was used to generate results shown in Figure 3, Figure 4, and Figure A1. 

 
KsMm=KsMr/MmMr;
MrMm=1/MmMr;
KfKs=KfMr/KsMr;

KuMm=(1-alpha)*KsMm+alpha^2*KfKs*KsMm/(phi_o+(alpha-phi_o)*KfKs);
KuMr=KuMm*MmMr;
KmMm=(1-alpha)*KsMm;
KmMr=KmMm*MmMr;
KfMm=KfKs*KsMm;
a1=(KmMm+4/3)*(KuMm-KmMm)/(alpha^2*MrMm*(KuMm+4/3));
a2=-(KuMm-KmMm)/(alpha*(KuMm+4/3));
b1=-(r_ratio^(2/3))*(KuMm-KmMm)/(alpha*(KuMm+4/3));
b2=-(r_ratio^(-1/3))*(r_ratio-1)*MrMm/(3*(KuMm+4/3));
c1=4*r_ratio*MmMr*(KuMm-KmMm)/(alpha*(KuMm+4/3));
c2=1+(r_ratio-1)*(4/3)/(KuMm+4/3);
d1=-3*r_ratio*KlMr-b1*3*KlMr*(r_ratio^(1/3));
d2=-b2*3*KlMr*(r_ratio^(1/3));
e0=4*(MmMr-1);
f1=a1;
f2=a2*e0-d2*e0+3*r_ratio*KlMr;
f3=-d1;
% f4=delta*KlMr;   %%%%%linear: Delta-dependent
g1=c1+d1;
g2=c2*e0+d2*e0-4*MmMr*r_ratio-3*r_ratio*KlMr;
h0=f3-f2*g1/g2;
% h1=f4+f2*f4/g2;    %%%%linear: Delta-dependent

t=t_range(1):dt:t_range(2);

M_inject=delta_m*(t-(t-tau).*heaviside(t-tau))/tau;
F4=KlMr*M_inject;
H1=F4+f2*F4/g2;

r=r_ratio^(-1/3):dr:1;
m_r=zeros(size(r));
sigma_r=NaN*ones(size(m_r));
u_r=NaN*ones(size(m_r));
M=NaN*ones(size(t));
M(1)=0;
tensial_t=NaN*ones(size(t));
m_edge_t=tensial_t;
%Initial velues
m_r(1)=H1(1)/f1; 

u1=-g1*M/g2-F4(1)/g2;
u0=zeros(size(u1));
zeta=4*(MmMr-1)*u1;

Pl_t=d1*M+d2*zeta-3*r_ratio*KlMr*u1+KlMr*delta_m*(t-(t-tau).*heaviside(t-tau))/tau;

count=0;
for ii=1:numel(t)
  
    dmdr1=(circshift(m_r,-1)-circshift(m_r,1))/(2*dr);
    dmdr1(1)=NaN;%we don't need the inner boundary point, we will set its velue directly later.
    dmdr1(end)=0;%imegine an out point m_(N+1)=m(N-1), s.t. dm/dr=0
    dmdr2=(circshift(m_r,-1)+circshift(m_r,1)-2*m_r)/dr^2;
    dmdr2(1)=NaN; %we don't need the inner boundary point, we will set its velue directly later.
    dmdr2(end)=(2*m_r(end-1)-2*m_r(end))/dr^2; %imegine an out point m_(N+1)=m(N-1), s.t. dm/dr=0
    
    dmdt=dmdr2+2*dmdr1./r;
    m_current=m_r;

    m_r=m_current+dmdt*dt; %update values in the shell
    M(ii)=sum(r(1:end-1).^2.*m_r(2:end))*dr;  %update M
    m_r(1)=H1(ii)/f1-h0*M(ii)/f1; %update end point of m --- m is updated
   
    %Update assosiated quantities
    u1(ii)=-g1*M(ii)/g2-F4(ii)/g2;
    tensial_t(ii)=2*u1(ii);
    zeta(ii)=4*(MmMr-1)*u1(ii);
    u0(ii)=b1*M(ii)+b2*zeta(ii)+u1(ii)*r_ratio^(2/3);
    Pl_t(ii)=d1*M(ii)+d2*zeta(ii)-3*r_ratio*KlMr*u1(ii)+KlMr*delta_m*(t(ii)-(t(ii)-tau).*heaviside(t(ii)-tau))/tau;
   % Pf_edge_t(ii)=a1*m_r(end)+a2*zeta(ii);
    Pf_r=a1*m_r+a2*zeta(ii);
    P_r=MmMr*4*(KuMr-KmMr)*m_r/(3*alpha*(KuMr+4*MmMr/3))-KuMr*zeta(ii)/(KuMr+4*MmMr/3);
   
    dphi_r=(1-(1-phi_o)/(1-alpha))*(P_r-Pf_r)/KsMr;
    Dphi_t(ii)=dphi_r(1);
    %    m_edge_t(ii)=m_r(end);
  %  for jj=1:numel(r)-1
  %  sigma_r(jj)=zeta(ii)-4*u1(ii)/(r(jj).^3)+c1*(r(jj).^(-3)/r_ratio)*sum(r(jj:end-1).^2.*m_r(jj+1:end))*dr;
  % end
  %  sigma_r(end)=0;
  
%  for jj=1:numel(r)-1
%     u_r(jj)=u1(ii)/r(jj)^2+b1*(r(jj)^(-2)/r_ratio^(2/3))*sum(r(jj:end-1).^2.*m_r(jj+1:end))*dr+zeta(ii)*(1/r(jj)^2-r(jj))*(b2/((r_ratio^(-1/3))*(r_ratio-1)));
%  end
%     u_r(end)=u1(ii);
%    
%     if((ii==1)||(mod(ii,50)==0))
%        figure(1);
%          
%         count=count+1;
%       aa=plot(r,u_r,'-','linewidth',10,'color','k');   
%         hold all;
%         
%         ylabel('normalized displacement');
%       %  xlabel('radial position');
%         set(gca,'fontsize',40);
%         set(gca,'ylim',[0 0.0003]);
%         set(gca,'xtick',[0.5 1],'xticklabel',{'r_o','R_o'});box off;
%         title('');
%         if ii==1
%             pause;
%         end
%         pause(0.02);
%         if (ii==10000) 
%              hold all;
%             bb=plot(r,u_r,'--','linewidth',5,'color',[0.5 0.5 0.5]);  
%             title('injection terminates')
%             pause(1);
%         end
%        delete(aa);
%     end    

%     if((ii==1)||(mod(ii,50)==0))
%         subplot(1,3,1);
%         plot(r,u_r,'-','linewidth',6);
%         ylabel('u (R_o^{-1})');
%         xlabel('r (R_o^{-1})');set(gca,'xtick',[0.5 1]);set(gca,'ytick',[0 2e-4]);
%        set(gca,'fontsize',20);
%        %title('deformation')
%         %title(['t=',num2str(t(ii)),' \tau_{diff}']);
%         set(gca,'ylim',[0 3e-4]);
%         set(gca,'xlim',[0.5 1]);
%         
%       subplot(1,3,2);
%         plot(r,dphi_r,'-','Linewidth',6);
%         ylabel('\Delta\phi');
%         xlabel('r (R_o^{-1})');set(gca,'xtick',[0.5 1]);set(gca,'ytick',[0 10e-4])
%         set(gca,'fontsize',20);
%        % title('porosity change ');
%         %title(num2str(t(ii)));
%         set(gca,'ylim',[-1e-4 14e-4]);
%         set(gca,'xlim',[0.5 1]);
%         
%      subplot(1,3,3);
%         plot(r,Pf_r-P_r,'-','Linewidth',6);
%    %     ylabel('P_f (\mu_r^{-1})');
%         xlabel('r (R_o^{-1})');set(gca,'xtick',[0.5 1]);
%         %set(gca,'ytick',[0 10e-4])
%         set(gca,'fontsize',20);
%        % title('pore pressure');
%         %title(num2str(t(ii)));
%         set(gca,'ylim',[-0.1e-4 4e-4]);
%         set(gca,'xlim',[0.5 1]);
%         pause(0.01);
%         set(gcf,'color','w');
%     end
%     
%        subplot(3,1,1);
%        plot(r,m_r,'.');set(gca,'ylim',[0 h1/f1]);title('m');
%        subplot(3,1,2);
%        plot(r,Pf_r,'.');set(gca,'ylim',[a2*zeta(1),a1*h1/f1+a2*zeta(1)]);title('P_f');
%        subplot(3,1,3);
%        plot(r,u_r,'.');set(gca,'ylim',[0.0034 0.0244]);title('u_r');
%        pause(0.001);
%      end
     %Record current values
end

M_s_t=3*r_ratio*M;
% DelU_edge_t=(KuMm-KmMm)*m_edge_t/(alpha*(KuMm+4/3))+zeta/(KuMm+4/3);
% Sigma_r_edge2_t=(KmMm+4/3)*DelU_edge_t-alpha*Pf_edge_t-4*u1;
% dPhi_t=m_edge_t-phi_o*Pf_edge_t/KfMm;