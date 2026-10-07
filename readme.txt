================================================================================
                           SynRec - USER MANUAL
         Synchronized Dual-Target Camera Recording & Live Stream App
================================================================================

OVERVIEW
--------
SynRec is a cross-platform Flutter application designed to pair two or more devices
(Android phones, Windows PCs, Mac PCs) over a local Wi-Fi, Mobile Hotspot, or
Bluetooth network.

It allows a "Master" device (Target A) to remotely view the live camera feed of a
"Slave" device (Target B) with ultra-low latency, and trigger synchronized photo
captures or video recordings simultaneously across all linked devices.

--------------------------------------------------------------------------------
1. CORE CONCEPTS & TARGET ROLES
--------------------------------------------------------------------------------
* TARGET A (MASTER):
  - Acts as the primary controller.
  - Can view the live screen/camera feed of the 1st linked Slave device in real time.
  - Triggers synchronized photo captures or video recordings across all linked Slave targets.

* TARGET B (SLAVE):
  - Listens for remote trigger commands (via direct TCP sockets, paired sockets, or Bluetooth LE).
  - Streams its camera feed to the Master target over the local Wi-Fi IP network (Port 8890).
  - Automatically executes photo captures or starts/stops recording when instructed by the Master.

--------------------------------------------------------------------------------
2. APP NAVIGATION & FRAGMENTS
--------------------------------------------------------------------------------
The top strap container (Red for Master, Indigo for Slave) controls role selection
and fragment navigation.

* FRAGMENT 1: "synrec"
  - Displays the local camera feed (or virtual webcam feed on PC).
  - Provides full control strap for device pairing, photo taking, video recording,
    stopping, and saving.

* FRAGMENT 2: "synviewrec"
  - When linked on a Master target: Displays the live camera feed of the 1st Slave target
    with ultra-low latency (Socket/HTTP stream over Port 8890).
  - Allows the Master target to trigger synchronized recordings or photos while viewing
    the Slave's live camera feed.

* SWITCHING FRAGMENTS:
  - On the top red strap, tap the Right Arrow (>) next to "synrec" to switch to "synviewrec".
  - On "synviewrec", tap the Left Arrow (<) next to "synviewrec" to return to "synrec".

--------------------------------------------------------------------------------
3. SETUP & DEVICE LINKING
--------------------------------------------------------------------------------
STEP 1: NETWORK CONNECTION
  - Ensure both devices are connected to the same Wi-Fi network OR connect the
    Slave target to the Master target's Mobile Hotspot (192.168.43.1).

STEP 2: ROLE SELECTION
  - On Device 1 (Controller): Check the "Master" checkbox on the top red strap.
  - On Device 2 (Camera/Slave): Uncheck "Master" to set it as "Slave".

STEP 3: PAIRING / LINKING
  - Method A (Auto-Discovery):
    Open the top-right menu (three dots) -> "Devices Around" -> tap "Search".
    Nearby devices will be discovered automatically. Check the box next to your
    target device to select it as a candidate.
  - Method B (Manual IP Entry):
    On the bottom control strap, tap the "+" button ("Add Target Device IP").
    Enter the Slave's Name and IP address (e.g. 192.168.178.25), then tap "Add & Link".
  - Method C (Direct Link):
    Select the target device from the dropdown on the bottom strap and tap "Link".

--------------------------------------------------------------------------------
4. RECORDING & PHOTO CONTROLS
--------------------------------------------------------------------------------
Located on the Floating Control Strap at the bottom of the screen:

  [Photo]     Captures a photo instantly on the Master device and sends a
              synchronized 'TAKE_PHOTO' trigger file to all linked Slave targets.

  [Record]    Starts video recording locally and sends a 'start.txt' trigger
              file to initiate synced recording on all linked Slave targets.

  [Stop Rec]  Stops active video recording locally and sends a 'stop.txt' trigger
              file to stop recording on all linked Slave targets.

  [Save]      Saves the recorded temporary video file as 'recxxxx.mp4' to
              local storage / Gallery.

--------------------------------------------------------------------------------
5. TOP MENU (THREE DOTS)
--------------------------------------------------------------------------------
  - Info & Sync Logs:
    Displays local Device Name, IP Address, Active Role, Link Status, and
    live history logs of trigger files sent/received.

  - Camera Current Setting:
    Displays camera hardware status, lens direction, resolution preset, and
    orientation details.

  - Devices Around:
    Displays local IP info and a list of candidate network/Bluetooth devices
    around for multi-device linking.

--------------------------------------------------------------------------------
6. TROUBLESHOOTING & NETWORK TIPS
--------------------------------------------------------------------------------
  - Connection Timed Out / Refused:
    Ensure both devices are on the same Wi-Fi subnet. Verify that firewalls on
    Windows/Mac allow incoming connections on Ports 8888, 8889, and 8890.

  - Low-Latency Stream Not Appearing on "synviewrec":
    Verify that the Slave device is in "Slave" mode (Master unchecked) and that
    its IP address is checked in "Devices Around" or selected in the device dropdown.

================================================================================
