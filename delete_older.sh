#!/bin/sh

export LANG=C LC_ALL=C PATH=/usr/bin:/bin
mongo --quiet Pastedance << 'EOT'
db.Pastedance.count()
db.Pastedance.remove({$where: function() {
        var now = parseInt((new Date).getTime() / 1000);
        return this.time + (86400 * 7)  <  now;
    }
});
db.Pastedance.count()
EOT
