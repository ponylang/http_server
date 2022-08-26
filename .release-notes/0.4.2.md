## Updated default connection heartbeat length

Previously, the default connection heartbeat was incorrectly set to 1ms. We've updated it to the value it was intended to be: 1000ms.

Sending a heartbeat every millisecond was excessive, and this change should improve performance slightly.

