# **Debian Package**  
## **1. Build the Package**  
To build the Debian package, run the following command from the root of the project:  
bash  
dpkg-buildpackage -us -uc -b   
## **2. Inspect the Package Without Installing It**  
Navigate to the parent directory where the generated .deb package is located:  
bash  
cd ..   
List the generated packages:  
bash  
ls protonplus_*.deb   
Inspect the package metadata and calculated dependencies:  
bash  
dpkg -I protonplus_0.6.9_amd64.deb   
List all files included in the package:  
bash  
dpkg -c protonplus_0.6.9_amd64.deb   
Check the package for common Debian packaging issues:  
bash  
lintian protonplus_0.6.9_amd64.deb   
## **3. Install the Package**  
Install the generated package on your system using APT:  
bash  
sudo apt install ./protonplus_0.6.9_amd64.deb   
APT will automatically handle the package dependencies.  
## **4. Verify the Installation**  
Check the files installed by the package:  
bash  
dpkg -L protonplus | grep -E "bin/|\\.desktop|\\.gschema|metainfo"   
You can then launch ProtonPlus using its application ID:  
bash  
com.vysp3r.ProtonPlus   
Alternatively, use the executable name found in the package contents (dpkg -c).  
   
