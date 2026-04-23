/*
Wirt OÜ
© 2024 Hannes Tamme
*/

module arrow(l){
    h = l * sqrt(3) / 2;
    linear_extrude(l/3)
        polygon(points=
            [[0,0],
            [l/3, 0],
            [l/3, - l/2],
            [l/(3/2), - l/2],
            [l/(3/2), 0],
            [l, 0],
            [l/2, h]]);
};

module logo(l){
    rotate([0,-45,-45]){
        arrow(l);
            translate([l/3,-l/(3/2),-l/3])
            rotate([-90,0,90])
                arrow(l);
            translate([l/(3/2),-l/3,l/3])
            rotate([0,90,-90])
                arrow(l);
        }
}

logo(10);