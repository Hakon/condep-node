﻿using System;
using System.IO;
using System.Security.Cryptography.X509Certificates;
using Org.BouncyCastle.Asn1.X509;
using Org.BouncyCastle.Crypto;
using Org.BouncyCastle.Crypto.Generators;
using Org.BouncyCastle.Crypto.Prng;
using Org.BouncyCastle.Math;
using Org.BouncyCastle.Pkcs;
using Org.BouncyCastle.Security;
using Org.BouncyCastle.Utilities;
using Org.BouncyCastle.X509;

namespace ConDep.Node.Tests
{
    public enum CertStrength
    {
        bits_512 = 512, bits_1024 = 1024, bits_2048 = 2048, bits_4096 = 4096
    }

    public class X509CertBuilder
    {
        const string SignatureAlgorithm = "SHA256WithRSA";
        private readonly int _strength;
        private readonly CryptoApiRandomGenerator _randomGenerator = new CryptoApiRandomGenerator();
        private readonly X509V3CertificateGenerator _certificateGenerator = new X509V3CertificateGenerator();
        private readonly SecureRandom _random;
        private readonly X509Name _issuer;

        public X509CertBuilder(string issuer, CertStrength certStrength)
        {
            _random = new SecureRandom(_randomGenerator);
            _issuer = new X509Name(issuer);
            _strength = (int)certStrength;

        }

        public X509Certificate2 MakeCertificate(string password,
            string issuedToDomainName,
            string friendlyName,
            int validDays)
        {
            _certificateGenerator.Reset();
            _certificateGenerator.SetSignatureAlgorithm(SignatureAlgorithm);
            var serialNumber = BigIntegers.CreateRandomInRange(BigInteger.One, BigInteger.ValueOf(Int64.MaxValue), _random);
            _certificateGenerator.SetSerialNumber(serialNumber);

            _certificateGenerator.SetSubjectDN(new X509Name(issuedToDomainName));
            _certificateGenerator.SetIssuerDN(_issuer);

            var utcNow = DateTime.UtcNow.AddDays(-1);
            _certificateGenerator.SetNotBefore(utcNow);
            _certificateGenerator.SetNotAfter(utcNow.AddDays(validDays));
            var keyGenerationParameters = new KeyGenerationParameters(_random, _strength);

            var keyPairGenerator = new RsaKeyPairGenerator();
            keyPairGenerator.Init(keyGenerationParameters);
            var subjectKeyPair = keyPairGenerator.GenerateKeyPair();

            _certificateGenerator.SetPublicKey(subjectKeyPair.Public);
            var issuerKeyPair = subjectKeyPair;
            var certificate = _certificateGenerator.Generate(issuerKeyPair.Private, _random);

            var store = new Pkcs12Store();
            var certificateEntry = new X509CertificateEntry(certificate);
            store.SetCertificateEntry(friendlyName, certificateEntry);
            store.SetKeyEntry(friendlyName, new AsymmetricKeyEntry(subjectKeyPair.Private), new[] { certificateEntry });

            using (var stream = new MemoryStream())
            {
                store.Save(stream, password.ToCharArray(), _random);
                return new X509Certificate2(stream.ToArray(), password, X509KeyStorageFlags.PersistKeySet | X509KeyStorageFlags.Exportable);
            }
        }
    }
}