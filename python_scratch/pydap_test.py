from pydap.client import open_url
pyds = open_url(
    'http://test.opendap.org:8080/opendap/catalog/ghrsst/20210102090000-JPL-L4_GHRSST-SSTfnd-MUR-GLOB-v02.0-fv04.1.nc', protocol='dap4')
pyds.tree()

print(pyds['sst_anomaly'].shape)
