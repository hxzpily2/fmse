

package com.dash.utils {
public class Manifest {
    public function Manifest() {
        throw new Error("It's a static class");
    }

    public static function toSeconds(value:String):Number {

        // format: "PT\d+H\d+M\d+S"; "S" means seconds, "M" means minutes and "H" means hours

        var match:Array;

        match = value.match(/([\d.]+)S/);
        var seconds:Number = match ? Number(match[1]) : 0;

        match = value.match(/([\d.]+)M/);
        var minutes:Number = match ? Number(match[1]) : 0;

        match = value.match(/([\d.]+)H/);
        var hours:Number = match ? Number(match[1]) : 0;

        return (hours * 60 * 60) + (minutes * 60) + seconds;
    }
}
}
