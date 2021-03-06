import retrieve_test, os
from config_bonn import appendix, cluster, tag, arc, filters, filter_root

path='/nfs/slac/g/ki/ki05/anja/SUBARU/%(cluster)s/' % {'cluster':cluster}
filterzero = filters[0]
params = {'path' : path, 'filter': filterzero, 'cluster': cluster, 'appendix': appendix}
img =  '/%(path)s/%(filter)s/SCIENCE/coadd_%(cluster)s%(appendix)s/coadd.fits' % params
sdsscat = '/%(path)s/PHOTOMETRY/sdssstar.cat' % params 
galaxycat = '/%(path)s/PHOTOMETRY/all.cat' % params 
output = '/%(path)s/PHOTOMETRY/cat/all_merg.cat' % params 
type = 'star' 

ThreeSecond = 1

if ThreeSecond:
    compcat1 = galaxycat #'/%(path)s/PHOTOMETRY/compare.cat' % params                                                
    compcat2 = '/%(path)s/PHOTOMETRY/compare2.cat' % params 
    sdsscat = '/tmp/MACS0417-11output.cat'
    command = 'ldacrenkey -i ' + sdsscat + ' -o /tmp/sdsscat.cat -k ALPHA_J2000_W-C-RC Ra DELTA_J2000_W-C-RC Dec -t STDTAB'
    print command
    os.system(command)
     
    command = "match_simple.sh %(galaxycat)s %(sdsscat)s %(output)s" % {'galaxycat': compcat1 , 'sdsscat': '/tmp/sdsscat.cat', 'output': output} 
    print command
    os.system(command)

else:
    retrieve_test.run(img,sdsscat,type)
    #command = "match_sdss.sh %(PATH1)s %(PATH2)s" % {'PATH1': path, 'PATH2': 'PHOTOMETRY'} 
    command = "match_simple.sh %(galaxycat)s %(sdsscat)s %(output)s" % {'galaxycat': galaxycat, 'sdsscat': sdsscat, 'output': output} 
    print command
    os.system(command)
