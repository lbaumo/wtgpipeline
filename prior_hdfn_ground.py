# HISTORY COMMENTS (TE)
# ====================
#
# 11.05.2009:
# The code now uses 'mumpy' instead of 'Numeric'. The Numeric
# version did not work with Python 2.5 and higher. 

from bpz_tools import *

def function(z,m,nt):
    """HDFN prior for the main six types of Benitez 2000
    Returns an array pi[z[:],:6]
    The input magnitude is F814W AB
    Slightly modified version to allow very low-z redshifts
    (modification by Thomas Erben; 12.06.2008)
    """	   
    mmax=28.

    if nt<>6:
	print "Wrong number of template spectra!"
	sys.exit()

    global zt_at_a
    nz=len(z)
    momin_hdf=20.
    if m>32.: m=32.
    if m<20.: m=20.    
    a=array((2.465,1.806,1.806,0.906,0.906,0.906))
    zo=array((0.431,0.390,0.390,0.0626,0.0626,0.0626))
    km=array((0.0913,0.0636,0.0636,0.123,0.123,0.123))
    fo_t=array((0.35,0.25,0.25))
    k_t=array((0.450,0.147,0.147))
    dm=m-momin_hdf
    zmt=clip(zo+km*dm,0.01,15.)
    zmt_at_a=zmt**(a)
    #We define z**a as global to keep it 
    #between function calls. That way it is 
    # estimated only once
    try:
	zt_at_a.shape
    except NameError:
	zt_at_a = power.outer(z, a)
	
    #Morphological fractions
    f_t = zeros((len(a),), Float)
    f_t[:3] = fo_t * exp(-k_t * dm)
    f_t[3:] = (1. - add.reduce(f_t[:3])) / 3.
    #Formula:
    #zm=zo+km*(m_m_min)
    #p(z|T,m)=(z**a)*exp(-(z/zm)**a)
    #p_i=zt_at_a[:nz,:6]*exp(-clip(zt_at_a[:nz,:6]/zmt_at_a[:6],0.,700.))
    #
    # The '0.05' in the first term softens the prior at the low-z end
    # and allows more low redshift galaxies. This seems to better
    # represent the z-distribution for ground-based data such as
    # the CFHTLS:
    p_i=(zt_at_a[:nz,:6]+0.05)*exp(-clip(zt_at_a[:nz,:6]/zmt_at_a[:6],0.,700.))
    #This eliminates the very low level tails of the priors
    #norm=add.reduce(p_i[:nz,:6],0)
    #p_i[:nz,:6]=where(less(p_i[:nz,:6]/norm[:6],1e-2/float(nz)),
    #0.,p_i[:nz,:6]/norm[:6])
    norm=add.reduce(p_i[:nz,:6],0)
    p_i[:nz,:6]=p_i[:nz,:6]/norm[:6]*f_t[:6]
    return p_i
