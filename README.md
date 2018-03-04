# Multi-scale, Multi-object Star Model detection algorithm
multi-scale multi-object star model Matlab code for single shot object detection & recognition. 
Trained using one or few examples per object, can support up to few thousands of objects at once.
Authors:
Leonid Karlinsky (karlinka@ibm.il.com), Joseph Shtok (josephs@il.ibm.com)
CVAR group, IBM Research AI, Haifa, Israel. July 2017.

The algorithm is described in detail in the paper (see bibtex below):
L. Karlinsky, J. Shtok, Y. Tzur, A. Tzadok,  "Fine-grained recognition of thousands of object categories with single-example Training".CVPR 2017

Its manifestation, implemented in the provided code, can be used as follows:
1. prepare a training directory, in which representative images of each category are given in a separate folder. In the demo script we provide usage example for 
   both the 'InVitro' directory of the GroZi-120 dataset (active) and for the 'Food' folder of the GFroZi2.3k set (commented out).
2. The code produces a database of categories, saved ( in this code) as 'db_grozi.mat', and a model ready to be employed for object detection.
3. When run on test images, the code produces list of detected bounding boxes, accompanied with category index and score.

Deployment and usage:
1. Download the repository and unzip into a folder of your choice. We refer to it as a 'rootPath'.
2. Download the vlfeat library, https://github.com/vlfeat/vlfeat/tree/master, and deploy it in rootPath/toolbox/vlfeat/. 
   Please do not forget to download the precompiled binaries package ( see http://www.vlfeat.org/download.html) for vlfeat, and merge its files into the vlfeat installation folder.
   Our code was tested on versions 0.9.20, 0.9.21 of the vl-feat toolbox. 
   
2. Open the main script, main_runThrough.m, and edit the first block of code, "set up libraries". Specifically,
	2.a update the 'rootPath' to the correct path (no backslash in the end of string)
	2.b set up the test data root, 'test_examples_root_path'. In our demo the data is the GroZi-120 dataset, available
	at http://grozi.calit2.net/grozi.html. Please notice that the GroZi-3.2k dataset, previously published at Marian George's 
	ETH Zurich webpage and used in our paper, is no longer seems to be available.

3. Execute the main_runThrough.m to produce a model from a set of training images and to test the detector on a few sample images.
	We also provide an auxiliary funtion to retrieve many frames from a video and run the test on them (commented out).
		

Remarks:
	1. In GroZi120 dataset, inVitro\16\web\JPEG\web2.jpg is perceived in Matlab as corrupt.
	2. The current 'data' folder contains a few sample images from the GroiZi3.2k dataset and the detection results on thuse images. 
	    The model, trained on GroiZi3.2k dataset and producing this reults, will be released in a separate location.


If you use whole or part of this code, please cite the following paper:
@article{karlinsky17msmo_star,
	Author = {Leonid Karlinsky, Joseph Shtok, Yochay Tzur, Assaf Tzadok},
	Title = {Fine-grained recognition of thousands of object categories with single-example training},
	Journal = {CVPR},
	Year = {2017}
}

Legal notice:
Licensed Materials - Property of IBM
5748-XX8
(c) Copyright IBM Corp. 1992, 1993 All Rights Reserved
US Government Users Restricted Rights - Use, duplication or
disclosure restricted by GSA ADP Schedule Contract with
IBM Corp.