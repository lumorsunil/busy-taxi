pub const Level = struct {
    numberOfCustomersToDeliver: u8,
    deliveredCustomers: u8 = 0,

    pub fn init(numberOfCustomersToDeliver: u8) Level {
        return Level{
            .numberOfCustomersToDeliver = numberOfCustomersToDeliver,
        };
    }

    pub fn isLevelComplete(self: Level) bool {
        return self.deliveredCustomers >= self.numberOfCustomersToDeliver;
    }
};
