
package com.dash.boxes {
import flash.errors.IllegalOperationError;
import flash.utils.ByteArray;

internal class Box {
    protected const SIZE_AND_TYPE:uint = 8;

    private var _end:uint;

    public function Box(offset:uint, size:uint) {
        _end = offset + size;
    }

    public function get end():uint {
        return _end;
    }

    public function parse(ba:ByteArray):void {
        while (ba.bytesAvailable) {
            var offset:uint = ba.position;
            var size:uint = ba.readUnsignedInt();
            var type:String = ba.readUTFBytes(4);

            var parsed:Object = parseChildBox(type, offset, size, ba);

            if (parsed == false) {
                if (ba.position < _end) { // skip
                    ba.position += size - SIZE_AND_TYPE;
                } else { // quit
                    ba.position = _end;
                    return;
                }
            }
        }
    }

    protected function parseChildBox(type:String, offset:uint, size:uint, ba:ByteArray):Boolean {
        throw new IllegalOperationError("Method not implemented");
    }
}
}