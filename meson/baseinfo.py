import platform
plat = (platform.platform())
if platform.system() == "Linux":
    plat = platform.freedesktop_os_release()["NAME"] + " : " + plat
print(plat)
