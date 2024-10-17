import glob
import os.path
import shutil
import sys
import config

source_dir = '/home/pi/Videos'
targ_dir = config.targ_dir

isExists = os.path.exists(targ_dir)
if not isExists:
    os.makedirs(targ_dir)

for file in sorted(glob.glob(os.path.join(source_dir, "*.avi"))):
    #if os.path.split(file)[1] not in sorted(glob.glob(os.path.join(targ_dir, "*.avi"))):
    filename = os.path.split(file)[1]
    if os.path.isfile(os.path.join(targ_dir, filename)) == False: 
        try:
            shutil.copy(file, targ_dir)
            print(f'SUCCESS: {file} copied to {targ_dir}')
        except Exception as e:
            print(f'ERROR: {e}')
            sys.exit()
    else:
        if os.path.getsize(file) != os.path.getsize(os.path.join(targ_dir, filename)):
            try:
                shutil.copy(file, targ_dir)
                print(f"CHANGE: File size wasn't correct! Recopied the file again: {filename}")
            except Exception as e:
                print(f'ERROR: {e}')
                sys.exit()
        else:
            pass