import os
from glob import  glob
import sys
from PIL import Image
from tqdm import tqdm
import argparse
from skimage.io import imread, imsave
import numpy as np

import tkinter as tk
from tkinter import ttk
from tkinter import filedialog, LabelFrame
import warnings
warnings.filterwarnings("ignore")

path = os.path.dirname(sys.argv[0])
path = os.path.abspath(path)
#print('Appending {}'.format(path))
sys.path.append(path)



# ======================================================================
root = tk.Tk()
root.title('EDF & Stitch from Nikon Biopipeline')
# setting the windows size
root.geometry("850x220")  # Width x height
root.resizable(False,False)

def getInputFolderPath():
    folder_selected = filedialog.askdirectory()
    inputpath.set(folder_selected)

def getInputFilePath():
    folder_selected = filedialog.askopenfilename(filetypes=[('ND2 Files','*.nd2')])
    inputfile.set(folder_selected)


def getOutputFolderPath():
    folder_selected = filedialog.askdirectory()
    outputpath.set(folder_selected)


def submit():
    imgdir = inputpath.get()
    imgfile = inputfile.get()
    outdir = outputpath.get()
    res = " " in outdir
    if res == True:
        print('ERROR: Output folder contains SPACE. Remove all SPACEs from output folder.')
        print('ERROR: Current output folder: {}'.format(outdir))
        sys.exit()


    ncpu = numcpu.get()

    path = os.path.realpath(sys.argv[0])
    path = os.path.dirname(path)
    path = os.path.join(path, 'nikon_biopipeline_processing.py ')
    # Use --atlasdir="path" --> The double quote and equal-to ensures the space in the path is respected
    # Using --atlasdir path or --atlasdir "path" does not work if there are spaces in  path, only arg equalto quote path unquote works
    if len(imgfile)==0:
        cmd = 'python ' + path + ' -i="' + imgdir + '" -o="' + str(outdir) + '" ' + ' -n=' + str(ncpu)
    else:
        cmd = 'python ' + path + ' -i="' + imgfile + '" -o="' + str(outdir) + '" ' + ' -n=' + str(ncpu)
    print(cmd)
    os.system(cmd)


    root.destroy()


if __name__ == "__main__":


    # declaring string variable

    inputpath = tk.StringVar()
    inputfile = tk.StringVar()
    outputpath = tk.StringVar()


    numcpu = tk.IntVar()



    frame1 = LabelFrame(root, text='Inputs')
    a = tk.Label(frame1, text="Input folder with unstitched ND2 files", padx=10)
    a.grid(row=1, column=1)
    E = tk.Entry(frame1, textvariable=inputpath, width=50)
    E.grid(row=1, column=2, ipadx=60)
    btnFind = ttk.Button(frame1, text="Browse Folder", command=getInputFolderPath)
    btnFind.grid(row=1, column=3)

    a = tk.Label(frame1, text="OR", padx=10)
    a.grid(row=2, column=2)

    a = tk.Label(frame1, text="Input unstitched ND2 file", padx=10)
    a.grid(row=3, column=1)
    E = tk.Entry(frame1, textvariable=inputfile, width=50)
    E.grid(row=3, column=2, ipadx=60)
    btnFind = ttk.Button(frame1, text="Browse File", command=getInputFilePath)
    btnFind.grid(row=3, column=3)

    numcpu_label = tk.Label(frame1, text='Number of CPUs to use (per image)')
    numcpu_entry = tk.Entry(frame1, textvariable=numcpu, width=8)
    numcpu.set(12)

    numcpu_label.grid(row=4, column=1, padx=20)
    numcpu_entry.grid(row=4, column=2, padx=5)
    frame1.grid(row=0, column=0, sticky='ew')

    frame2 = LabelFrame(root, text='Output')
    # Some blank row
    a = tk.Label(frame2, text="", padx=10)
    a.grid(row=1, column=2)
    a = tk.Label(frame2, text="Output folder where stitched image(s) will be written", padx=10)
    a.grid(row=2, column=1)
    E = tk.Entry(frame2, textvariable=outputpath, width=40)
    E.grid(row=2, column=2, ipadx=60)
    btnFind = ttk.Button(frame2, text="Browse Folder", command=getOutputFolderPath)
    btnFind.grid(row=2, column=3)

    frame2.grid(row=1, column=0, sticky='ew')


    # Some blank row
    a = tk.Label(root, text="", padx=10)
    a.grid(row=3, column=0)

    sub_btn = tk.Button(root, text='Run', command=submit)
    sub_btn.grid(row=4,column=0)


    # performing an infinite loop
    # for the window to display
    root.mainloop()
