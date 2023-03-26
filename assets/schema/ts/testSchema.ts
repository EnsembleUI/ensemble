interface Address {
  street_address: string;
  city: string;
  state: string;
  zip: string;
}

export interface Person {
  name: string;
  age: number;
  email: string;
  address: Address;
}
